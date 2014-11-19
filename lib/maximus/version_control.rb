require 'git'
require 'active_support'
require 'active_support/core_ext/object/blank'
require 'rainbow'
require 'rainbow/ext/string'

module Maximus
  class GitControl

    def initialize(opts = {})
      opts[:root_dir] ||= is_rails? ? Rails.root : Dir.pwd
      opts[:is_dev] ||= true
      @root_dir = opts[:root_dir]
      opts[:log] ||= true
      log = is_rails? ? Logger.new("#{@root_dir}/log/maximus_git.log") : nil
      log = opts[:log] ? log : nil
      @g = Git.open(@root_dir, :log => log)
      @is_dev = opts[:is_dev]
      @dev_mode = false
    end

    #Regular git data for POSTing
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
    # Returns hash grouped by file extension (defined in assoc) => { filename, changes: (changed line ranges) }
    def compare(sha1 = master_commit.sha, sha2 = sha)
      git_diff = `git rev-list #{sha1}..#{sha2} --no-merges`.split("\n")
      diff_return = {}
      abort 'No new commits'.color(:blue) if git_diff.length == 0
      # Reverse so that we go in chronological order
      git_diff.reverse.each do |git_sha|
        lines_added = `#{File.expand_path("../config/git-lines.sh", __FILE__)} #{git_sha}`.split("\n")
        new_lines = {}
        lines_added.each do |filename|
          fsplit = filename.split(':')
          new_lines[fsplit[0]] ||= []
          new_lines[fsplit[0]] << fsplit[1]
          new_lines[fsplit[0]].uniq!
        end
        new_lines.delete("/dev/null")

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
                unless new_lines[c].blank?
                  files[child] = [
                    filename: "#{@root_dir}/#{c}",
                    changes: new_lines[c]
                  ]
                else
                  files[child] = [] #hack to ignore deleted files
                end
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
    def lint(git_shas = compare)
      base_branch = branch
      git_shas.each do |sha, exts|
        quietly { `git checkout #{sha} -b maximus_#{sha}` }
        puts sha.to_s.color(:blue) if @is_dev
        exts.each do |ext, files|
          file_list = files.map { |f| f[:filename] }.compact
          file_list_joined = ext == :ruby ? file_list.join(' ') : file_list.join(',') #lints accept files differently
          opts = { is_dev: @is_dev, path: "\"#{file_list_joined}\"", from_git: true }
          case ext
            when :js
              match_lines(LintTask.new(opts).jshint, files, 'jshint') # Is there a way to not have task explicitly declared here? Maybe attr_accessor on the LintTask? Or similar?
            when :scss
              match_lines(LintTask.new(opts).scsslint, files, 'scsslint')
              StatisticTask.new.stylestats unless @dev_mode
            when :ruby
              match_lines(LintTask.new(opts).rubocop, files, 'rubocop')
              match_lines(LintTask.new(opts).railsbp, files, 'railsbp')
              match_lines(LintTask.new(opts).brakeman, files, 'brakeman')
            when :rails
              match_lines(LintTask.new(opts).railsbp, files, 'railsbp')
          end
        end
        quietly {
          @g.branch(base_branch).checkout
          @g.branch("maximus_#{sha}").delete
        }
      end
    end

    private

    # Compare lint output with lines changed in commit
    # Returns array of lints that match the lines in commit
    def match_lines(lint_task, files, task)
      all_files = {}
      files.each do |file|
        unless lint_task[:data].blank? # sometimes data will be blank but this is good - it means no errors raised in the lint
          lint = lint_task[:data][file[:filename].to_s]

          # convert line ranges from string to expanded array - I'm sure there's a better way of doing this
          changes_array = file[:changes].map { |ch| ch.split("..").map(&:to_i) }
          expanded = changes_array.map { |e| (e[0]..e[1]).to_a }.flatten!
          revert_name = file[:filename].gsub("#{@root_dir}/", '')
          unless lint.blank?
            all_files[revert_name] = []

            # originally I tried .map and delete_if, but this works, and the other method didn't cover all bases. Gotta be a better way to write this though
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
      lint_task[:lint].refine(all_files, task, @is_dev) #optionally include is_dev param
    end

    def sha
      @g.object('HEAD').sha
    end

    def branch
      `env -i git rev-parse --abbrev-ref HEAD`.strip!
    end

    def master_commit
      @g.branches[:master].gcommit
    end

    def vccommit
      @g.gcommit(sha)
    end

    def diff
      @g.diff(vccommit, master_commit).stats
    end

    def remote
      @g.remotes.first.url unless @g.remotes.blank?
    end

    def user
      @g.config('user.name')
    end

    def email
      @g.config('user.email')
    end

  end
end
