module Maximus
  # Methods used for git commands
  # @since 0.1.7
  module GitHelper

    # Find first commit
    # @since 0.1.5
    # @return [String]
    def first_commit
      `git -C #{@config.working_dir} rev-list --max-parents=0 HEAD`.strip!
    end

    # Get commit before current
    # @since 0.1.5
    # @param current_commit [String] (head_sha) commit to start at
    # @param previous_by [Integer] (1) commit n commits ago
    # @return [String]
    def previous_commit(current_commit = head_sha, previous_by = 1)
      `git -C #{@config.working_dir} rev-list --max-count=#{previous_by + 1} #{current_commit} --reverse | head -n1`.strip!
    end

    # Get last commit on current branch
    # @return [String] sha
    def head_sha
      @g.object('HEAD').sha
    end

    # Get current branch name
    # @return [String]
    def branch
      `env -i git rev-parse --abbrev-ref HEAD`.strip!
    end

    # Get last commit sha on the master branch
    # @return [String]
    def master_commit_sha
      @g.branches[:master].blank? ? head_sha : @g.branches[:master].gcommit.sha
    end

    # Get remote URL
    # @return [String, nil] nil returns if remotes is blank
    def remote
      @g.remotes.first.url unless @g.remotes.blank?
    end

    # Return file names of working copy files
    # @since 0.1.7
    def working_copy_files
      `git -C #{@config.working_dir} diff --name-only`
    end

    # Grab files by sha
    # @since 0.1.7
    def files_by_sha(commit_sha)
      `git -C #{@config.working_dir} show --pretty="format:" --name-only #{commit_sha}`
    end

    # Retrieve list of shas between two commits
    # @since 0.1.7
    def sha_range(sha1, sha2)
      `git -C #{@config.working_dir} rev-list #{sha1}..#{sha2} --no-merges`
    end

    # A commit's insertions, deletions, and file names
    # @since 0.1.7
    def commit_information(commit_sha)
      # Start after the commit message
      `git -C #{@config.working_dir} log --numstat --oneline #{commit_sha}`.split("\n")[1..-1]
    end

    # Retrieve insertions by commit with a custom script
    # @since 0.1.7
    # @return [Array]
    def lines_by_sha(commit_sha)
      `#{File.join(File.dirname(__FILE__), 'reporter', 'git-lines.sh')} #{@config.working_dir} #{commit_sha}`.split("\n")
    end

  end
end
