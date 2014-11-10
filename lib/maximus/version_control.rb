require 'git'
require 'active_support'
require 'active_support/core_ext/object/blank'

module Maximus
  module VersionControl
    class GitControl

      attr_accessor :vcoutput

      def initialize
        @root_dir = is_rails? ? Rails.root : Dir.pwd
        log = is_rails? ? Logger.new("#{@root_dir}/log/maximus_git.log") : nil
        @g = Git.open(@root_dir, :log => log)
      end

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

      def compare(sha1 = master_commit.sha, sha2 = sha)
        git_diff = `git rev-list #{sha1}..#{sha2} --no-merges`.split("\n")
        diff_return = {}

        #Reverse so that we go in chronological order
        git_diff.reverse.each do |git_sha|

          lines_added = `#{File.expand_path("../config/git-lines.sh", __FILE__)} #{git_sha}`.split("\n")
          new_lines = {}
          lines_added.each do |filename|
            fsplit = filename.split(':')
            new_lines[fsplit[0]] ||= []
            new_lines[fsplit[0]] << fsplit[1]
            new_lines[fsplit[0]].uniq!
          end
          # For later - http://stackoverflow.com/questions/53472/best-way-to-convert-a-ruby-string-range-to-a-range-object
          new_lines.delete("/dev/null")

          git = @g.gcommit(git_sha)
          files = `git show --pretty="format:" --name-only #{git_sha}`.split("\n").group_by { |f| f.split('.').pop }
          files.compact!

          assoc = {
            js:     ['js', 'json'],
            scss:   ['scss', 'sass'],
            rails:  ['slim', 'haml'],
            ruby:   ['rb', 'Gemfile', 'lock', 'yml'],
            ignore: [nil, 'gitignore', 'scssc']
          }
          assoc.each do |ext, related|
            files[ext] ||= []
            related.each do |child|
              unless files[child].blank?
                files[child].each do |c|
                  files[child] = [
                    filename: c,
                    changes: new_lines[c]
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

      def lint(shas = compare)
        base_branch = branch
        shas.each do |sha, exts|
          quietly { `git checkout #{sha} -b maximus_#{sha}` }
          exts.each do |ext, files|
            unless files.blank?
              file_list = files.map { |f| (f[:filename] unless f[:changes].blank?) }.compact
              unless file_list.blank?
                file_list = ext == :ruby ? file_list.join(' ') : file_list.join(',')
                opts = { dev: true, path: "\"#{file_list}\"" }
                LintTask.new(opts).jshint if ext == :js
                LintTask.new(opts).scsslint if ext == :scss
                StatisticTask.new(opts).stylestats if ext == :scss
                LintTask.new(opts).rubocop if ext == :ruby
                LintTask.new(opts).railsbp if ext == :ruby || :rails
                LintTask.new(opts).brakeman if ext == :ruby
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
end
