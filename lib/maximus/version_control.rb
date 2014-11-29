require 'git'
require 'active_support'
require 'active_support/core_ext/object/blank'
require 'rainbow'
require 'rainbow/ext/string'

module Maximus
  class GitControl

    include Helper

    def initialize(opts = {})
      @is_rails = is_rails?
      opts[:root_dir] ||= @is_rails ? Rails.root : Dir.pwd
      opts[:is_dev] = true if opts[:is_dev].nil?
      @root_dir = opts[:root_dir]
      opts[:log] = true if opts[:log].nil?
      log = @is_rails ? Logger.new("#{@root_dir}/log/maximus_git.log") : nil
      log = opts[:log] ? log : nil
      @g = Git.open(@root_dir, :log => log)
      @is_dev = opts[:is_dev]
      @dev_mode = false
    end

    # Returns Hash of git data
    def export
      {
        git: {
          commitsha: sha,
          branch: branch,
          message: vccommit.message,
          deletions: diff[:total][:deletions],
          insertions: diff[:total][:insertions],
          raw_data: diff,
          remote_repo: remote
        },
        user: {
          name: user,
          email: email
        },
      }
    end

    # Compare two commits and get line number ranges of changed patches
    # Returns Hash grouped by file extension (defined in assoc) => { filename, changes: (changed line ranges) }
    # Example: 'sha' => { rb: {filename: 'file.rb', changes: { ['0..4'], ['10..20'] }  }}
    def compare(sha1 = master_commit.sha, sha2 = sha)
      diff_return = {}
      git_diff = `git rev-list #{sha1}..#{sha2} --no-merges`.split("\n")
      if git_diff.length == 0
        puts 'No new commits'.color(:blue)
        return false # Fail silently
      end
      # Reverse so that we go in chronological order
      git_diff.reverse.each do |git_sha|
        new_lines = lines_added(git_sha)

        # Grab all files in that commit and group them by extension
        files = `git show --pretty="format:" --name-only #{git_sha}`.split("\n").group_by { |f| f.split('.').pop }

        files.is_a?(Array) ? files.compact! : files.delete_if { |k,v| k.nil? }

        assoc = {
          js:     ['js'],
          scss:   ['scss', 'sass'],
          rails:  ['slim', 'haml'],
          ruby:   ['rb', 'Gemfile', 'lock', 'yml', 'Rakefile', 'ru', 'rdoc'],
          ignore: [nil, 'gitignore', 'scssc', 'log', 'keep', 'concern']
        }

        assoc.each do |ext, related|
          files[ext] ||= []
          related.each do |child|
            unless files[child].blank?
              files[child].each do |c|
                files[child] = new_lines[c].blank? ? [] : [ filename: "#{@root_dir}/#{c}", changes: new_lines[c] ] # hack to ignore deleted files
              end
              files[ext].concat(files[child])
              files.delete(child)
            end
          end
        end
        files.delete(:ignore)
        files.delete_if { |k,v| v.blank? }
        diff_return[git_sha.to_sym] = files
      end
      diff_return
    end

    # Run appropriate lint for every sha in commit history
    # Creates new branch based on each sha, then deletes it
    # The match_lines method here is essential
    # Executes the LintTask after filtering it with match_lines
    def lint(git_shas = compare)
      return false if git_shas.blank?
      base_branch = branch
      git_shas.each do |sha, exts|
        quietly { `git checkout #{sha} -b maximus_#{sha}` } # TODO - better way to silence git, in case there's a real error?
        puts "Commit #{sha.to_s}".color(:blue) if @is_dev
        exts.each do |ext, files|
          file_list = files.map { |f| f[:filename] }.compact
          file_list_joined = ext == :ruby ? file_list.join(' ') : file_list.join(',') #lints accept files differently
          opts = {
            is_dev: @is_dev,
            path: "\"#{file_list_joined}\"",
            from_git: true
          }
          case ext
            when :js
              match_lines(LintTask.new(opts).jshint, files)
              @lint_output[:statistics] << StatisticTask.new.phantomas unless @dev_mode
            when :scss
              match_lines(LintTask.new(opts).scsslint, files)
              StatisticTask.new.stylestats unless @dev_mode
            when :ruby
              match_lines(LintTask.new(opts).rubocop, files)
              match_lines(LintTask.new(opts).railsbp, files)
              match_lines(LintTask.new(opts).brakeman, files)
            when :rails
              match_lines(LintTask.new(opts).railsbp, files)
          end
        end
        quietly {
          @g.branch(base_branch).checkout
          @g.branch("maximus_#{sha}").delete
        } # TODO - better way to silence git, in case there's a real error?
      end
    end

    # Run appropriate lint for every sha in commit history
    # Creates new branch based on each sha, then deletes it
    # Different from above method as it returns the entire lint, not just the lines relevant to commit
    # Returns Hash with all data grouped by task
    # TODO - could this be DRY'd up with the above method?
    def all_lints_and_stats(git_shas = compare)
      return false if git_shas.blank?
      base_branch = branch
      @lint_output = {}
      @lint_output[:statistics] = {}
      @lint_output[:lints] = {}
      git_shas.each do |sha, exts|
        quietly { `git checkout #{sha} -b maximus_#{sha}` } # TODO - better way to silence git, in case there's a real error?
        puts "Commit #{sha.to_s}".color(:blue) if @is_dev
        exts.each do |ext, files|
          puts ext
          puts @dev_mode
          opts = {
            is_dev: @is_dev,
            from_git: false
          }
          case ext
            when :js
              @lint_output[:lints][:jshint] = LintTask.new(opts).jshint
              @lint_output[:statistics][:phantomas] = StatisticTask.new({is_dev: @is_dev}).phantomas unless @dev_mode
            when :scss
              @lint_output[:lints][:scsslint] = LintTask.new(opts).scsslint
              @lint_output[:statistics][:stylestats] = StatisticTask.new({is_dev: @is_dev}).stylestats unless @dev_mode
              @lint_output[:statistics][:phantomas] ||= StatisticTask.new({is_dev: @is_dev}).phantomas unless @dev_mode # TODO - double pipe here is best way to say, if it's already run, don't run again, right?
            when :ruby
              @lint_output[:lints][:rubocop] = LintTask.new(opts).rubocop
              @lint_output[:lints][:railsbp] = LintTask.new(opts).railsbp
              @lint_output[:lints][:brakeman] = LintTask.new(opts).brakeman
            when :rails
              @lint_output[:lints][:railsbp] = LintTask.new(opts).railsbp
          end
        end
        quietly {
          @g.branch(base_branch).checkout
          @g.branch("maximus_#{sha}").delete
        } # TODO - better way to silence git, in case there's a real error?
        @lint_output
      end
    end


    protected

    # Returns array of ranges by lines added in a commit by file name
    # {'filename' => ['0..10', '11..14']}
    def lines_added(git_sha)
      lines_added = `#{File.join(File.dirname(__FILE__), 'config/git-lines.sh')} #{git_sha}`.split("\n")
      new_lines = {}
      lines_added.each do |filename|
        fsplit = filename.split(':')
        new_lines[fsplit[0]] ||= [] # if file isn't already part of the array
        new_lines[fsplit[0]] << fsplit[1]
        new_lines[fsplit[0]].uniq! # no repeats
      end
      new_lines.delete("/dev/null")
      new_lines
    end

    # Compare lint output with lines changed in commit
    # Returns Array of lints that match the lines in commit and then refines them
    def match_lines(lint_task, files)
      all_files = {}
      files.each do |file|
        unless lint_task[:data].blank? # sometimes data will be blank but this is good - it means no errors raised in the lint
          lint = lint_task[:data][file[:filename].to_s]

          # TODO - convert line ranges from string to expanded array - I'm sure there's a better way of doing this
          changes_array = file[:changes].map { |ch| ch.split("..").map(&:to_i) }
          expanded = changes_array.map { |e| (e[0]..e[1]).to_a }.flatten!
          revert_name = file[:filename].gsub("#{@root_dir}/", '')
          unless lint.blank?
            all_files[revert_name] = []

            # TODO - originally I tried .map and delete_if, but this works, and the other method didn't cover all bases. Gotta be a better way to write this though
            lint.each do |l|
              if expanded.include?(l['line'].to_i)
                all_files[revert_name] << l
              end
            end
          end
        else
          all_files[file[:filename].to_s.gsub("#{@root_dir}/", '')] = [] #it's good, but we still need to store the filename
        end
      end
      lint_task[:lint].refine(all_files, lint_task[:task])
    end

    # Get last commit on current branch
    # Returns String
    def sha
      @g.object('HEAD').sha
    end

    # Get branch name
    # Returns String
    def branch
      `env -i git rev-parse --abbrev-ref HEAD`.strip!
    end

    # Get last commit on the master branch
    # Returns Git::Object
    def master_commit
      @g.branches[:master].gcommit
    end

    # Store last commit as Ruby Git::Object
    # Returns Git::Object
    def vccommit
      @g.gcommit(sha)
    end

    # Get general stats of commit on HEAD versus last commit on master branch
    # Returns Git::Diff
    def diff
      @g.diff(vccommit, master_commit).stats
    end

    # Get remote URL
    # Returns String or nil if remotes is blank
    def remote
      @g.remotes.first.url unless @g.remotes.blank?
    end

    # Get git user as defined in git's global config
    # Returns String
    def user
      @g.config('user.name')
    end

    # Get git user's email as defined in git's global config
    # Returns String
    def email
      @g.config('user.email')
    end

  end
end
