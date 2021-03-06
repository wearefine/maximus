require 'git'
require 'active_support/core_ext/kernel/reporting'

module Maximus
  # Git management
  # @since 0.1.0
  class GitControl

    include Helper
    include GitHelper

    # Set up instance variables
    #
    # Inherits settings from {Config#initialize}
    # @param opts [Hash] options passed directly to config
    # @option opts [Config object] :config custom Maximus::Config object
    # @option opts [String] :commit accepts sha, "working", "last", or "master".
    def initialize(opts = {})
      opts[:config] ||= Maximus::Config.new({ commit: opts[:commit] })
      @config = opts[:config]

      @settings = @config.settings
      @psuedo_commit = ( !@settings[:commit].blank? && %w(working last master).include?(@settings[:commit]) )

      @g = Git.open(@config.working_dir)
    end

    # 30,000 foot view of a commit
    # @param commit_sha [String] (head_sha) the sha of the commit
    # @return [Hash] commit data
    def commit_export(commit_sha = head_sha)
      commit_sha = commit_sha.to_s

      ce_commit = @g.gcommit(commit_sha)

      if first_commit == commit_sha
        ce_diff = diff_initial(first_commit)
      else
        last_commit = @g.gcommit(previous_commit(commit_sha))
        ce_diff = diff(last_commit, ce_commit)
      end

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
    # @param sha1 [String]
    # @param sha2 [String]
    # @return [Hash] diff_return files changed grouped by file extension and line number
    def compare(sha1 = master_commit_sha, sha2 = head_sha)
      diff_return = {}

      sha1 = define_psuedo_commit if @settings[:commit]
      # Reverse so that we go in chronological order
      git_spread = commit_range(sha1, sha2).reverse

      git_spread.each do |git_sha|

        # Grab all files in that commit and group them by extension
        #   If working copy, just give the diff names of the files changed
        files = @psuedo_commit ? working_copy_files : files_by_sha(git_sha)

        diff_return[git_sha] = match_associations(git_sha, files)
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
      git_ouput = {}

      git_shas.each do |sha, exts|
        create_branch(sha) unless @psuedo_commit
        sha = sha.to_s
        puts sha.color(:blue)

        exts.each do |ext, files|
          # For relevant_lines data
          lint_opts = {
            git_files: files,
            config: @config,
            file_paths: (lint_file_paths(files, ext) if lint_by_path)
          }

          git_ouput[sha] = nuclear ? lints_and_stats_nuclear(lint_opts) : lints_and_stats_switch(ext, lint_opts)

        end

        destroy_branch(base_branch, sha) unless @psuedo_commit
      end

      git_ouput
    end

    # Define associations to linters based on file extension
    # @return [Hash] linters and extension arrays
    def associations
      {
        css:    ['css'],
        scss:   ['scss', 'sass'],
        js:     ['js'],
        ruby:   ['rb', 'Gemfile', 'lock', 'yml', 'Rakefile', 'ru', 'rdoc', 'rake', 'Capfile', 'jbuilder'],
        rails:  ['slim', 'haml', 'jbuilder', 'erb'],
        images: ['png', 'jpg', 'jpeg', 'gif'],
        static: ['pdf', 'txt', 'doc', 'docx', 'csv', 'xls', 'xlsx'],
        markup: ['html', 'xml', 'xhtml'],
        markdown: ['md', 'markdown', 'mdown'],
        php:    ['php', 'ini']
      }
    end


    protected

      # Retrieve shas of all commits to be evaluated
      # @since 0.1.5
      #
      # If working directory, just have a single item array.
      #   The space here is important because git-lines checks for a second arg,
      #   and if one is present, it runs git diff without a commit
      #   or a comparison to a commit.
      #
      # Include the first sha because rev-list is doing a traversal
      #   So sha1 is never included
      #
      # @param sha1 [String]
      # @param sha2 [String]
      # @return [Array] shas
      def commit_range(sha1, sha2)
        git_spread = @psuedo_commit ? "git #{sha1}" : sha_range(sha1, sha2)
        git_spread = git_spread.nil? ? [] : git_spread.split("\n")

        git_spread << sha1 unless @psuedo_commit
        git_spread
      end

      # Get sha if words passed for :commit config option
      # @since 0.1.5
      # @return [String] commit sha
      def define_psuedo_commit
        case @settings[:commit]
          when 'master' then master_commit_sha
          when 'last' then previous_commit(head_sha)
          when 'working' then 'working'
          else @settings[:commit]
        end
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
      def lines_added(commit_sha)
        new_lines = {}
        git_lines = lines_by_sha(commit_sha)
        git_lines.each do |filename|
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

      # Get general stats of commit on HEAD versus last commit on master branch
      # @modified 0.1.4
      # @param old_commit [Git::Object]
      # @param new_commit [Git::Object]
      # @return [Git::Diff] hash of abbreviated, useful stats with added lines
      def diff(old_commit, new_commit)
        stats = @g.diff(old_commit, new_commit).stats
        lines = lines_added(new_commit.sha)
        return if !lines.is_a?(Hash) || stats.blank?

        lines.each do |filename, filelines|
          stats[:files][filename][:lines_added] = filelines if stats[:files].key?(filename)
        end

        stats
      end

      # Get diff stats on just the initial commit
      # Ruby-git doesn't support this well
      # @see diff
      # @since 0.1.5
      # @param commit_sha [String]
      # @return [Hash] stat data similar to Ruby-git's Diff.stats return
      def diff_initial(commit_sha)
        data = commit_information(commit_sha)
        value = {
          total: {
            insertions: 0,
            deletions: 0,
            lines: 0,
            files: data.length
          },
          files: {}
        }
        data.each do |d|
          item = d.split("\t")
          insertions = item[0].to_i
          value[:total][:insertions] += insertions
          value[:total][:lines] += insertions
          value[:files][item[2]] = {
            insertions: insertions,
            deletions: 0,
            lines_added: ["0..#{item[0]}"]
          }
        end
        value
      end

      # Associate files by extension and match their changes
      # @since 0.1.5
      # @param commit_sha [String]
      # @param files [String] list of files from git
      # @return [Hash] files with matched extensions and changes
      def match_associations(commit_sha, files)
        new_lines = lines_added(commit_sha)

        files = files.split("\n").group_by { |f| f.split('.').pop }

        associations.each do |ext, related|
          files[ext] ||= []
          related.each do |child|
            next if files[child].blank?

            files[child].each do |c|
              # hack to ignore deleted files
              files[child] = new_lines[c].blank? ? [] : [ filename: File.join(@config.working_dir, c), changes: new_lines[c] ]
            end
            files[ext].concat(files[child])
            files.delete(child)
          end
        end

        files.delete_if { |k,v| v.blank? || k.nil? }
        files
      end

      # All data retrieved from reports
      # @since 0.1.6
      # @param lint_opts [Hash]
      # @return [Hash]
      def lints_and_stats_nuclear(lint_opts)
        {
          lints: {
            scsslint: Maximus::Scsslint.new(lint_opts).result,
            jshint: Maximus::Jshint.new(lint_opts).result,
            rubocop: Maximus::Rubocop.new(lint_opts).result,
            railsbp: Maximus::Railsbp.new(lint_opts).result,
            brakeman: Maximus::Brakeman.new(lint_opts).result
          },
          statistics: {
            stylestat: Maximus::Stylestats.new({config: @config}).result,
            phantomas: Maximus::Phantomas.new({config: @config}).result,
            wraith: Maximus::Wraith.new({config: @config}).result
          }
        }
      end

      # Specific data retrieved by file extension
      # @since 0.1.6
      # @param ext [String]
      # @param lint_opts [Hash]
      # @return [Hash]
      def lints_and_stats_switch(ext, lint_opts)
        result = {
          lints: {},
          statistics: {}
        }

        lints = result[:lints]
        statistics = result[:statistics]

        case ext
          when :scss
            lints[:scsslint] = Maximus::Scsslint.new(lint_opts).result

            # @todo stylestat is singular here because model name in Rails is singular.
            #   But adding a .classify when it's converted to a model chops off the end s on 'phantomas',
            #   which breaks the model name.
            statistics[:stylestat] = Maximus::Stylestats.new({config: @config}).result

            # @todo double pipe here is best way to say, if it's already run, don't run again, right?
            statistics[:phantomas] ||= Maximus::Phantomas.new({config: @config}).result
            statistics[:wraith] ||= Maximus::Wraith.new({config: @config}).result
          when :js
            lints[:jshint] = Maximus::Jshint.new(lint_opts).result

            statistics[:phantomas] ||= Maximus::Phantomas.new({config: @config}).result

            # @todo double pipe here is best way to say, if it's already run, don't run again, right?
            statistics[:wraith] ||= Maximus::Wraith.new({config: @config}).result
          when :ruby
            lints[:rubocop] = Maximus::Rubocop.new(lint_opts).result
            lints[:railsbp] ||= Maximus::Railsbp.new(lint_opts).result
            lints[:brakeman] = Maximus::Brakeman.new(lint_opts).result
          when :rails
            lints[:railsbp] ||= Maximus::Railsbp.new(lint_opts).result
        end

        result
      end


    private

      # Create branch to run report on
      # @since 0.1.5
      # @param sha [String]
      def create_branch(sha)
        silence_stream(STDERR) { `git -C #{@config.working_dir} checkout #{sha} -b maximus_#{sha}` }
      end

      # Destroy created branch
      # @since 0.1.5
      # @param base_branch [String] branch we started on
      # @param sha [String] used to check against created branch name
      def destroy_branch(base_branch, sha)
        if base_branch == "maximus_#{sha}"
          @g.branch('master').checkout
        else
          @g.branch(base_branch).checkout
        end
        @g.branch("maximus_#{sha}").delete
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

  end
end
