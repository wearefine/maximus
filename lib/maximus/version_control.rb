require 'git'

module Maximus
  module VersionControl
    class GitControl

      attr_accessor :vcoutput

      def initialize(is_rails = true)
        @root_dir = is_rails ? Rails.root : Dir.pwd
        log = is_rails ? Logger.new("#{@root_dir}/log/maximus_git.log") : nil
        @g = Git.open(@root_dir, :log => log)
      end

      def project
        @root_dir.to_s.split('/').last
      end

      def sha
        @g.object('HEAD').sha
      end

      def branch
        `env -i git rev-parse --abbrev-ref HEAD`
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

      def export
        return {
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

    end
  end
end
