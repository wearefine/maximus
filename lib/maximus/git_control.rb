require 'git'

module Maximus
  # @since 0.1.0
  class GitControl

    include Helper

    # Git management
    #
    # Inherits settings from {Config#initialize}
    # @param opts [Hash] options passed directly to config
    # @option opts [Config object] :config custom Maximus::Config object
    # @option opts [String] :commit accepts sha, "working", "last", or "master".
    def initialize(opts = {})
      opts[:config] ||= Maximus::Config.new({ commit: opts[:commit] })
      @config ||= opts[:config]
      @settings ||= @config.settings
      @psuedo_commit = (!@settings[:commit].blank? && (@settings[:commit] == 'working' || @settings[:commit] == 'last' || @settings[:commit] == 'master') )
      @g = Git.open(@settings[:root_dir], :log => @settings[:git_log])
    end

    # 30,000 foot view of a commit
    # @param commit_sha [String] (sha) the sha of the commit
    # @return [Hash] commit data
    def commit_export(commit_sha = sha)
      ce_commit = vccommit(commit_sha)

      # For the git call, there's a trailing new line ("\n") that must be removed for
      #   the if statement to function properly
      first_commit = `git -C #{@settings[:root_dir]} rev-list --max-parents=0 HEAD`.strip!

      # This may come in as a symbol string (:"whatever") so convert it
      if first_commit == commit_sha.to_s
        last_commit = @g.gcommit(first_commit)
      else
        last_commit = @g.gcommit(`git -C #{@settings[:root_dir]} rev-parse #{commit_sha.to_s}^`.strip!)
      end

      ce_diff = diff(last_commit, ce_commit)

      {
        commit_sha: commit_sha,
        branch: branch,
        message: ce_commit.message,
        remote_repo: remote,
        git_author: ce_commit.author.name,
        git_author_email: ce_commit.author.email,
        commit_date: ce_commit.author.date.to_s,
        diff: ce_diff
      }
    end

    # Compare two commits and get line number ranges of changed patches
    #
    # @example output from the method
    #   {
    #     'sha': {
    #       rb: {
    #         filename: 'file.rb',
    #         changes: {
    #           ['0..4'],
    #           ['10..20']
    #         }
    #       }
    #     }
    #   }
    #
    # @return [Hash] diff_return files changed grouped by file extension and line number
    def compare(sha1 = master_commit.sha, sha2 = sha)
      diff_return = {}

      if @settings[:commit]
        sha1 = case @settings[:commit]
          when 'master' then master_commit.sha
          when 'last' then @g.object('HEAD^').sha
          when 'working' then 'working'
          else @settings[:commit]
        end
      end

      # If working directory, just have a single item array.
      #   The space here is important because git-lines checks for a second arg,
      #   and if one is present, it runs git diff without a commit
      #   or a comparison to a commit.
      git_diff = @psuedo_commit ? ["git #{sha1}"] : `git rev-list #{sha1}..#{sha2} --no-merges`.split("\n")

      # Include the first sha because rev-list is doing a traversal
      # So sha1 is never included
      git_diff << sha1 unless @psuedo_commit

      # Reverse so that we go in chronological order
      git_diff.reverse.each do |git_sha|
        new_lines = lines_added(git_sha)

        # Grab all files in that commit and group them by extension
        # If working copy, just give the diff names of the files changed
        files = @psuedo_commit ? `git diff --name-only` : `git show --pretty="format:" --name-only #{git_sha}`
        # File.extname is not used here in case dotfiles are encountered
        files = files.split("\n").group_by { |f| f.split('.').pop }

        # Don't worry about files that we don't have a lint or a statistic for
        flat_associations = associations.clone.flatten(2)
        files.delete_if { |k,v| !flat_associations.include?(k) || k.nil? }

        associations.each do |ext, related|
          files[ext] ||= []
          related.each do |child|
            unless files[child].blank?
              files[child].each do |c|
                # hack to ignore deleted files
                files[child] = new_lines[c].blank? ? [] : [ filename: "#{@settings[:root_dir]}/#{c}", changes: new_lines[c] ]
              end
              files[ext].concat(files[child])
              files.delete(child)
            end
          end
        end
        files.delete_if { |k,v| v.blank? }
        diff_return[git_sha.to_sym] = files
      end
      diff_return
    end

    # Run appropriate lint for every sha in commit history.
    # For each sha a new branch is created then deleted
    #
    # @example sample output
    #   {
    #     'sha': {
    #       lints: {
    #         scsslint: {
    #           files_inspec...
    #         },
    #       },
    #       statisti...
    #     },
    #     'sha'...
    #   }
    #
    # @see compare
    # @param lint_by_path [Boolean] only lint by files in git commit and
    #   not the commit as a whole
    # @param git_shas [Hash] (#compare) a hash of gitcommit shas
    #   and relevant file types in the commit
    # @param nuclear [Boolean] do everything regardless of what's in the commit
    # @return [Hash] data all data grouped by task
    def lints_and_stats(lint_by_path = false, git_shas = compare, nuclear = false)
      return false if git_shas.blank?
      base_branch = branch
      git_output = {}
      git_shas.each do |sha, exts|
        create_branch(sha) unless @psuedo_commit
        puts sha.to_s.color(:blue)
        git_output[sha.to_sym] = {
          lints: {},
          statistics: {}
        }
        lints = git_output[sha.to_sym][:lints]
        statistics = git_output[sha.to_sym][:statistics]
        lint_opts = {}

        # This is where everything goes down
        exts.each do |ext, files|
          # For relevant_lines data
          lint_opts = {
            git_files: files,
            config: @config
          }
          lint_opts[:file_paths] = lint_file_paths(files, ext) if lint_by_path
          if nuclear
            lints[:scsslint] = Maximus::Scsslint.new(lint_opts).result
            lints[:jshint] = Maximus::Jshint.new(lint_opts).result
            lints[:rubocop] = Maximus::Rubocop.new(lint_opts).result
            lints[:railsbp] = Maximus::Railsbp.new(lint_opts).result
            lints[:brakeman] = Maximus::Brakeman.new(lint_opts).result
            statistics[:stylestat] = Maximus::Stylestats.new({config: @config}).result
            statistics[:phantomas] = Maximus::Phantomas.new({config: @config}).result
            statistics[:wraith] = Maximus::Wraith.new({config: @config}).result
          else
            case ext
              when :scss
                lints[:scsslint] = Maximus::Scsslint.new(lint_opts).result

                # Do not run statistics if called from command line
                if @settings[:commit].blank?

                  # @todo stylestat is singular here because model name in Rails is singular.
                  #   But adding a .classify when it's converted to a model chops off the end s on 'phantomas',
                  #   which breaks the model name.
                  statistics[:stylestat] = Maximus::Stylestats.new({config: @config}).result

                  # @todo double pipe here is best way to say, if it's already run, don't run again, right?
                  statistics[:phantomas] ||= Maximus::Phantomas.new({config: @config}).result
                  statistics[:wraith] ||= Maximus::Wraith.new({config: @config}).result
                end
              when :js
                lints[:jshint] = Maximus::Jshint.new(lint_opts).result

                # Do not run statistics if called from command line
                if @settings[:commit].blank?

                  statistics[:phantomas] ||= Maximus::Phantomas.new({config: @config}).result

                  # @todo double pipe here is best way to say, if it's already run, don't run again, right?
                  statistics[:wraith] ||= Maximus::Wraith.new({config: @config}).result
                end
              when :ruby
                lints[:rubocop] = Maximus::Rubocop.new(lint_opts).result
                lints[:railsbp] ||= Maximus::Railsbp.new(lint_opts).result
                lints[:brakeman] = Maximus::Brakeman.new(lint_opts).result
              when :rails
                lints[:railsbp] ||= Maximus::Railsbp.new(lint_opts).result
            end
          end
        end
        destroy_branch(base_branch, sha) unless @psuedo_commit
      end
      git_output
    end


    protected

      # Create branch to run report on
      # @todo better way to silence git, in case there's a real error?
      # @since 0.1.5
      # @param sha [String]
      def create_branch(sha)
        quietly { `git checkout #{sha} -b maximus_#{sha}` }
      end

      # Destroy created branch
      # @todo better way to silence git, in case there's a real error?
      # @since 0.1.5
      # @param base_branch [String] branch we started on
      # @param sha [String] used to check against created branch name
      def destroy_branch(base_branch, sha)
        quietly {
          if base_branch == "maximus_#{sha}"
            @g.branch('master').checkout
          else
            @g.branch(base_branch).checkout
          end
          @g.branch("maximus_#{sha}").delete
        }
      end

      # Get list of file paths
      # @param files [Hash] hash of files denoted by key 'filename'
      # @param ext [String] file extension - different extensions are joined different ways
      # @return [String] file paths delimited by comma or space
      def lint_file_paths(files, ext)
        file_list = files.map { |f| f[:filename] }.compact
        # Lints accept files differently
        ext == :ruby ? file_list.join(' ') : file_list.join(',')
      end

      # Determine which lines were added (where and how many) in a commit
      #
      # @example output from method
      #   { 'filename': [
      #       '0..10',
      #       '11..14'
      #    ] }
      #
      # @param git_sha [String] sha of the commit
      # @return [Hash] ranges by lines added in a commit by file name
      def lines_added(git_sha)
        new_lines = {}
        lines_added = `#{File.join(File.dirname(__FILE__), 'reporter/git-lines.sh')} #{git_sha}`.split("\n")
        lines_added.each do |filename|
          fsplit = filename.split(':')
          # if file isn't already part of the array
          new_lines[fsplit[0]] ||= []
          new_lines[fsplit[0]] << fsplit[1] unless fsplit[1].nil?
          # no repeats
          new_lines[fsplit[0]].uniq!
        end
        new_lines.delete("/dev/null")
        new_lines
      end

      # Get last commit on current branch
      # @return [String] sha
      def sha
        @g.object('HEAD').sha
      end

      # Get current branch name
      # @return [String]
      def branch
        `env -i git rev-parse --abbrev-ref HEAD`.strip!
      end

      # Get last commit on the master branch
      # @return [Git::Object]
      def master_commit
        @g.branches[:master].gcommit
      end

      # Store last commit as Ruby Git::Object
      # @param commit_sha [String]
      # @return [Git::Object]
      def vccommit(commit_sha = sha)
        @g.gcommit(commit_sha)
      end

      # Get general stats of commit on HEAD versus last commit on master branch
      # @modified 0.1.4
      # @param old_commit [Git::Object]
      # @param new_commit [Git::Object]
      # @return [Git::Diff] hash of abbreviated, useful stats with added lines
      def diff(old_commit = master_commit, new_commit = vccommit)
        stats = @g.diff(old_commit, new_commit).stats
        lines = lines_added(new_commit.sha)
        return if !lines.is_a?(Hash) || stats.blank?
        lines.each do |filename, filelines|
          stats[:files][filename][:lines_added] = filelines if stats[:files].has_key?(filename)
        end
        stats
      end

      # Get remote URL
      # @return [String, nil] nil returns if remotes is blank
      def remote
        @g.remotes.first.url unless @g.remotes.blank?
      end

      # Define associations to linters based on file extension
      # @return [Hash] linters and extension arrays
      def associations
        {
          scss:   ['scss', 'sass'],
          js:     ['js'],
          ruby:   ['rb', 'Gemfile', 'lock', 'yml', 'Rakefile', 'ru', 'rdoc'],
          rails:  ['slim', 'haml']
        }
      end

  end
end
