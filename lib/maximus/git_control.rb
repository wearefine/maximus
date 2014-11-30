require 'git'
require 'active_support'
require 'active_support/core_ext/object/blank'
require 'rainbow'
require 'rainbow/ext/string'

module Maximus
  class GitControl

    include Helper

    def initialize(opts = {})
      opts[:is_dev] = true if opts[:is_dev].nil?
      opts[:log] = Logger.new('log/maximus_git.log') if opts[:log].nil?
      opts[:base_url] ||= 'http://localhost:3000'
      opts[:port] ||= ''
      opts[:root_dir] ||= root_dir
      log = opts[:log] ? log : nil
      @@log = mlog
      @opts = opts
      @is_dev = opts[:is_dev]

      @g = Git.open(@opts[:root_dir], :log => log)
    end

    # Returns Hash of commit data
    def commit_export(commitsha = sha)
      ce_commit = vccommit(commitsha)
      ce_diff = diff(ce_commit, @g.object('HEAD^'))
      {
        commitsha: commitsha,
        branch: branch,
        message: ce_commit.message,
        remote_repo: remote,
        git_author: ce_commit.author.name,
        git_author_email: ce_commit.author.email,
        diff: ce_diff
      }
    end

    # Compare two commits and get line number ranges of changed patches
    # Returns Hash grouped by file extension (defined in assoc) => { filename, changes: (changed line ranges) }
    # Example: 'sha' => { rb: {filename: 'file.rb', changes: { ['0..4'], ['10..20'] }  }}
    def compare(sha1 = master_commit.sha, sha2 = sha)
      diff_return = {}
      git_diff = `git rev-list #{sha1}..#{sha2} --no-merges`.split("\n")
      if git_diff.length == 0
        @@log.warn 'No new commits'
        return false # Fail silently
      end
      # Reverse so that we go in chronological order
      git_diff.reverse.each do |git_sha|
        new_lines = lines_added(git_sha)

        # Grab all files in that commit and group them by extension
        files = `git show --pretty="format:" --name-only #{git_sha}`.split("\n").group_by { |f| f.split('.').pop }

        files.is_a?(Array) ? files.compact! : files.delete_if { |k,v| k.nil? }

        assoc = {
          scss:   ['scss', 'sass'],
          js:     ['js'],
          ruby:   ['rb', 'Gemfile', 'lock', 'yml', 'Rakefile', 'ru', 'rdoc'],
          rails:  ['slim', 'haml'],
          ignore: [nil, 'gitignore', 'scssc', 'log', 'keep', 'concern']
        }

        assoc.each do |ext, related|
          files[ext] ||= []
          related.each do |child|
            unless files[child].blank?
              files[child].each do |c|
                files[child] = new_lines[c].blank? ? [] : [ filename: "#{@opts[:root_dir]}/#{c}", changes: new_lines[c] ] # hack to ignore deleted files
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
    # Executes the Lint after filtering it with match_lines
    def lint(git_shas = compare)
      return false if git_shas.blank?
      base_branch = branch
      git_shas.each do |sha, exts|
        quietly { `git checkout #{sha} -b maximus_#{sha}` } # TODO - better way to silence git, in case there's a real error?
        puts "Commit #{sha.to_s}".color(:blue) if @is_dev
        exts.each do |ext, files|
          lint_opts = {
            is_dev: @is_dev,
            path: "\"#{lint_file_paths(files, ext)}\"",
            from_git: true
          }
          case ext
            when :scss
              match_lines(Lint.new(lint_opts).scsslint, files)
              Statistic.new.stylestats
              Statistic.new.wraith
            when :js
              match_lines(Lint.new(lint_opts).jshint, files)
              Statistic.new.phantomas
            when :ruby
              match_lines(Lint.new(lint_opts).rubocop, files)
              match_lines(Lint.new(lint_opts).railsbp, files)
              match_lines(Lint.new(lint_opts).brakeman, files)
            when :rails
              match_lines(Lint.new(lint_opts).railsbp, files)
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
    # Example: { 'sha': { lints: { scsslint: { files_inspec... }, statisti... } }, 'sha...' }
    # TODO - could this be DRY'd up with the above method?
    def all_lints_and_stats(git_shas = compare)
      return false if git_shas.blank?
      base_branch = branch
      lint_output = {}
      git_shas.each do |sha, exts|
        quietly { `git checkout #{sha} -b maximus_#{sha}` } # TODO - better way to silence git, in case there's a real error?
        puts "Commit #{sha.to_s}".color(:blue) if @is_dev
        lint_output[sha.to_sym] = {
          lints: {},
          statistics: {}
        }
        lints = lint_output[sha.to_sym][:lints]
        statistics = lint_output[sha.to_sym][:statistics]
        exts.each do |ext, files|
          lint_opts = {
            is_dev: @is_dev,
            from_git: false
          }
          stat_opts = {
            is_dev: @is_dev,
            base_url: @opts[:base_url],
            port: @opts[:port],
            root_dir: @opts[:root_dir]
          }
          case ext
            when :scss
              lints[:scsslint] = Lint.new(lint_opts).scsslint
              # stylestat is singular here because model name in Rails is singular. But adding a .classify when it's converted to a model chops off the end s on 'phantomas', which breaks the model name. This could be a TODO
              statistics[:stylestat] = Statistic.new({is_dev: @is_dev}).stylestats
              # TODO - double pipe here is best way to say, if it's already run, don't run again, right?
              statistics[:phantomas] ||= Statistic.new(stat_opts).phantomas
              statistics[:wraith] = Statistic.new(stat_opts).wraith
            when :js
              lints[:jshint] = Lint.new(lint_opts).jshint
              statistics[:phantomas] = Statistic.new(stat_opts).phantomas
              # TODO - double pipe here is best way to say, if it's already run, don't run again, right?
              statistics[:wraith] ||= Statistic.new(stat_opts).wraith
            when :ruby
              lints[:rubocop] = Lint.new(lint_opts).rubocop
              lints[:railsbp] = Lint.new(lint_opts).railsbp
              lints[:brakeman] = Lint.new(lint_opts).brakeman
            when :rails
              lints[:railsbp] = Lint.new(lint_opts).railsbp
          end
        end
        quietly {
          @g.branch(base_branch).checkout
          @g.branch("maximus_#{sha}").delete
        } # TODO - better way to silence git, in case there's a real error?
      end
      lint_output
    end


    protected

    # Get list of file paths
    # Returns String delimited by comma or space
    def lint_file_paths(files, ext)
      file_list = files.map { |f| f[:filename] }.compact
      ext == :ruby ? file_list.join(' ') : file_list.join(',') #lints accept files differently
    end

    # Returns Array of ranges by lines added in a commit by file name
    # {'filename' => ['0..10', '11..14']}
    def lines_added(git_sha)
      lines_added = `#{File.join(File.dirname(__FILE__), 'reporter/git-lines.sh')} #{git_sha}`.split("\n")
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
          revert_name = file[:filename].gsub("#{@opts[:root_dir]}/", '')
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
          all_files[file[:filename].to_s.gsub("#{@opts[:root_dir]}/", '')] = [] #it's good, but we still need to store the filename
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
    def vccommit(commitsha = sha)
      @g.gcommit(commitsha)
    end

    # Get general stats of commit on HEAD versus last commit on master branch
    # Roadmap - include lines_added in this method's output
    # Returns Git::Diff
    def diff(new_commit = vccommit, old_commit = master_commit)
      @g.diff(new_commit, old_commit).stats
    end

    # Get remote URL
    # Returns String or nil if remotes is blank
    def remote
      @g.remotes.first.url unless @g.remotes.blank?
    end

  end
end
