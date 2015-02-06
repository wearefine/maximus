require 'thor'

# Command line abilities
# @since 0.1.0
class Maximus::CLI < Thor

  include Thor::Actions

  class_option :frontend, aliases: ['-f', '--front-end'], type: :boolean, default: false, lazy_default: false, desc: "Do front-end lints"
  class_option :backend, aliases: ['-b', '--back-end'], type: :boolean, default: false, lazy_default: false, desc: "Do back-end lints"
  class_option :statistics, aliases: ['-s'], type: :boolean, default: false, lazy_default: false, desc: "Do statistics"
  class_option :all, aliases: ['-a'], type: :boolean,  default: false, lazy_default: false, desc: "Do everything"

  class_option :filepath, aliases: ['-fp'], type: :array, default: [], desc: "Space-separated path(s) to files"
  class_option :urls, aliases: ['-u'], type: :array, desc: "Statistics only - Space-separated path(s) to relative URL paths"
  class_option :domain, aliases: ['-d'], type: :string, desc: "Statistics only - Web address (prepended to paths)"
  class_option :port, aliases: ['-po'], type: :numeric, desc: 'Statistics only - Port to use if required (appended to domain)'

  class_option :include, aliases: ['-i'], type: :array, default: [], desc: "Include only specific lints or statistics"
  class_option :exclude, aliases: ['-e'], type: :array, default: [], desc: "Exlude specific lints or statistics"

  class_option :config, aliases: ['-c'], type: :string, desc: 'Path to config file'

  class_option :git, aliases: ['-g', '--git', '--sha'], type: :string, default: 'working', banner: "working, last, master, or sha", desc: "Lint by commit or working copy"

  def initialize(*args)
    super
    @config ||= Maximus::Config.new(default_options)
  end

  desc "frontend", "Execute all front-end tasks"
  def frontend
    ['scsslint', 'jshint'].each { |e| check_exclude(e) }
    @config.destroy_temp
  end

  desc "backend", "Lint with all backend lints"
  def backend
    ['rubocop', 'railsbp', 'brakeman'].each { |e| check_exclude(e) }
    @config.destroy_temp
  end

  desc "statistics", "Run all statistics"
  def statistics
    ['stylestats', 'phantomas', 'wraith'].each { |e| check_exclude(e) }
    @config.destroy_temp
  end

  # Alias ruby to backend
  # (alias_method doesn't work because Thor requires a description)
  desc "ruby", "Lint with all ruby lints"
  def ruby
    backend
  end

  desc "git", "Display lint data based on working copy, last commit, master branch or specific sha"
  def git
    all_tasks = ['frontend', 'backend', 'statistics']
    # If all flag is enabled, run everything
    return all_tasks.each { |a| send(a) } if options[:all]
    # Lint by category unless all flags are blank
    return all_tasks.each { |a| check_option(a) } unless options[:frontend].blank? && options[:backend].blank? && options[:statistics].blank?
    # If include flag is enabled, run based on what's included
    return options[:include].each { |i| send(i) } unless options[:include].blank?
    # If all flag is not enabled, lint working copy as it's supposed to be
    @config.settings[:commit] = options[:git]
    Maximus::GitControl.new({config: @config}).lints_and_stats(true)
    @config.destroy_temp
  end

  # @todo something better than just installing in the global npm file
  desc "install", "Install all dependencies"
  def install
    `npm install -g jshint phantomas stylestats`
  end

  no_commands do
    # Only run command if option is present
    def check_option(opt)
      send(opt) if options[opt.to_sym]
    end
    # Don't run command if it's present in the exlude options
    def check_exclude(opt)
      send(opt) unless options[:exclude].include?(opt)
    end
    def default_options
      {
        file_paths: options[:filepath],
        paths: options[:urls],
        domain: options[:domain],
        port: options[:port],
        is_dev: true,
        config_file: options[:config]
      }
    end

    def scsslint
      Maximus::Scsslint.new({config: @config}).result
    end

    def jshint
      Maximus::Jshint.new({config: @config}).result
    end

    def rubocop
      Maximus::Rubocop.new({config: @config}).result
    end

    def railsbp
      Maximus::Railsbp.new({config: @config}).result
    end

    def brakeman
      Maximus::Brakeman.new({config: @config}).result
    end

    def stylestats
      Maximus::Stylestats.new({config: @config}).result
    end

    def phantomas
      Maximus::Phantomas.new({config: @config}).result
    end

    def wraith
      Maximus::Wraith.new({config: @config}).result
    end
  end

  default_task :git
end
