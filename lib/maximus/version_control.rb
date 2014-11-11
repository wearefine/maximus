require 'git'
require 'active_support'
require 'active_support/core_ext/object/blank'

module Maximus
  class GitControl

    def initialize
      @root_dir = is_rails? ? Rails.root : Dir.pwd
      log = is_rails? ? Logger.new("#{@root_dir}/log/maximus_git.log") : nil
      @g = Git.open(@root_dir, :log => log)
    end

    #Regular git data for POSTing
    def export
      {
        project: {
          name: project,
          remote_repo: remote
        },
        git: {
          commitsha: sha,
          branch: branch,
          message: vccommit.message,
          deletions: diff[:total][:deletions],
          insertions: diff[:total][:insertions],
          raw_data: diff
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

        git = @g.gcommit(git_sha)
        files = `git show --pretty="format:" --name-only #{git_sha}`.split("\n").group_by { |f| f.split('.').pop }
        files.compact!

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
                files[child] = [
                  filename: c,
                  changes: (new_lines[c] unless new_lines[c].blank?)
                ]
              end
              files[ext].concat(files[child])
              files.delete(child)
            end
          end
        end
        files.delete(:ignore)
        diff_return[git_sha.to_sym] = files
      end
      diff_return
    end

    # Run appropriate lint for every sha in commit history
    # Creates new branch based on each sha, then deletes it
    def lint(shas = compare)
      base_branch = branch
      shas.each do |sha, exts|
        quietly { `git checkout #{sha} -b maximus_#{sha}` }
        exts.each do |ext, files|
          unless files.blank?
            file_list = files.map { |f| (f[:filename] unless f[:changes].flatten.compact.blank?) }.compact
            unless file_list.blank?
              file_list_joined = ext == :ruby ? file_list.join(' ') : file_list.join(',') #lints accept files differently
              opts = { dev: true, path: "\"#{file_list_joined}\"" }
              case ext
                when :js
                  match_lines(LintTask.new(opts).jshint, files)
                when :scss
                  match_lines(LintTask.new(opts).scsslint, files)
                  StatisticTask.new({ dev: true }).stylestats
                when :ruby
                  match_lines(LintTask.new(opts).rubocop, files)
                  match_lines(LintTask.new(opts).railsbp, files)
                  match_lines(LintTask.new(opts).brakeman, files)
                when :rails
                  match_lines(LintTask.new(opts).railsbp, files)
              end
            end
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
    # returns array of lints that match the lines in commit
    def match_lines(output, files)
      return unless output[:raw_data]
      all_files = []
      files.each do |file|
        lint = output[:raw_data][file[:filename].to_s]

        #convert line ranges from string to expanded array - i'm sure there's a better way of doing this
        changes_array = file[:changes].map { |ch| ch.split("..").map(&:to_i) }
        expanded = changes_array.map { |e| (e[0]..e[1]).to_a }.flatten!

        all_files << lint.map { |l| l if expanded.include?(l['line'].to_i) } unless lint.blank?
      end
      all_files.flatten.compact
    end

    def project
      @root_dir.to_s.split('/').last
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
