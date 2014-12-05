require 'git'
require 'active_support'
require 'active_support/core_ext/object/blank'
require 'rainbow'
require 'rainbow/ext/string'

module Maximus
  class GitControl

    include Helper

    def initialize(opts = {})
      opts[:is_dev] ||= false
      opts[:log] = Logger.new('log/maximus_git.log') if opts[:log].nil?
      opts[:base_url] ||= 'http://localhost:3000'
      opts[:port] ||= ''
      opts[:root_dir] ||= root_dir
      log = opts[:log] ? log : nil
      @@log = mlog
      @@is_dev = opts[:is_dev]
      @opts = opts

      @psuedo_commit = (!@opts[:commit].blank? && @opts[:commit] == 'working')
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

      if @opts[:commit]
        sha1 = case @opts[:commit]
          when 'master' then master_commit.sha
          when 'last' then @g.object('HEAD^').sha
          when 'working' then 'working'
          else @opts[:commit]
        end
      end

      # if working directory, just have a single item array
      # the space here is important because git-lines checks for a second arg,
      # and if one is present, it runs git diff without a commit
      # or a comparison to a commit
      git_diff = @psuedo_commit ? ['working directory'] : `git rev-list #{sha1}..#{sha2} --no-merges`.split("\n")

      # Include the first sha because rev-list is doing a traversal
      # So sha1 is never included
      git_diff << sha1 unless @psuedo_commit

      # Reverse so that we go in chronological order
      git_diff.reverse.each do |git_sha|
        new_lines = lines_added(git_sha)

        # Grab all files in that commit and group them by extension
        # If working copy, just give the diff names of the files changed
        files = @psuedo_commit ? `git diff --name-only` : `git show --pretty="format:" --name-only #{git_sha}`
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
                files[child] = new_lines[c].blank? ? [] : [ filename: "#{@opts[:root_dir]}/#{c}", changes: new_lines[c] ]
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

    # Run appropriate lint for every sha in commit history
    # Creates new branch based on each sha, then deletes it
    # Different from above method as it returns the entire lint, not just the lines relevant to commit
    # Returns Hash with all data grouped by task
    # Example: { 'sha': { lints: { scsslint: { files_inspec... }, statisti... } }, 'sha...' }
    def lints_and_stats(lint_by_path = false, git_shas = compare)
      return false if git_shas.blank?
      base_branch = branch
      git_output = {}
      git_shas.each do |sha, exts|
        # TODO - better way to silence git, in case there's a real error?
        quietly { `git checkout #{sha} -b maximus_#{sha}` } unless @psuedo_commit
        puts sha.to_s.color(:blue) if @@is_dev
        git_output[sha.to_sym] = {
          lints: {},
          statistics: {}
        }
        lints = git_output[sha.to_sym][:lints]
        statistics = git_output[sha.to_sym][:statistics]
        lint_opts = {
          is_dev: @@is_dev,
          root_dir: @opts[:root_dir],
          commit: !@opts[:commit].blank?
        }
        stat_opts = {
          is_dev: @@is_dev,
          base_url: @opts[:base_url],
          port: @opts[:port],
          root_dir: @opts[:root_dir]
        }
        # This is where everything goes down
        exts.each do |ext, files|
          # For relevant_lines data
          lint_opts[:git_files] = files
          lint_opts[:path] = lint_file_paths(files, ext) if lint_by_path
          case ext
            when :scss
              lints[:scsslint] = Maximus::Scsslint.new(lint_opts).result

              # Do not run statistics if called by rake task :compare
              if lint_opts[:commit].blank?

                # stylestat is singular here because model name in Rails is singular.
                # But adding a .classify when it's converted to a model chops off the end s on 'phantomas',
                # which breaks the model name. This could be a TODO
                statistics[:stylestat] = Maximus::Stylestats.new(stat_opts).result

                # TODO - double pipe here is best way to say, if it's already run, don't run again, right?
                statistics[:phantomas] ||= Maximus::Phantomas.new(stat_opts).result
                statistics[:wraith] = Maximus::Wraith.new(stat_opts).result
              end
            when :js
              lints[:jshint] = Maximus::Jshint.new(lint_opts).result

              # Do not run statistics if called by rake task :compare
              if lint_opts[:commit].blank?

                statistics[:phantomas] = Maximus::Phantomas.new(stat_opts).result

                # TODO - double pipe here is best way to say, if it's already run, don't run again, right?
                statistics[:wraith] ||= Maximus::Wraith.new(stat_opts).result
              end
            when :ruby
              lints[:rubocop] = Maximus::Rubocop.new(lint_opts).result
              lints[:railsbp] = Maximus::Railsbp.new(lint_opts).result
              lints[:brakeman] = Maximus::Brakeman.new(lint_opts).result
            when :rails
              lints[:railsbp] ||= Maximus::Railsbp.new(lint_opts).result
          end
        end
        # TODO - better way to silence git, in case there's a real error?
        quietly {
          @g.branch(base_branch).checkout
          @g.branch("maximus_#{sha}").delete
        } unless @psuedo_commit
      end
      git_output
    end


    protected

    # Get list of file paths
    # Returns String delimited by comma or space
    def lint_file_paths(files, ext)
      file_list = files.map { |f| f[:filename] }.compact
      # Lints accept files differently
      ext == :ruby ? file_list.join(' ') : file_list.join(',')
    end

    # Returns Array of ranges by lines added in a commit by file name
    # {'filename' => ['0..10', '11..14']}
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

    # Define associations to linters based on file extension
    # Returns Hash of linters and extension arrays
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
