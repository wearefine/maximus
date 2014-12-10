require 'thor'

# @since 0.1.0
class Maximus::CLI < Thor
  include Thor::Actions
  class_option :path, aliases: ["-p", "-u", "\--url"], default: nil, desc: "Space-separated path(s) to URLs or files"
  class_option :frontend, default: false, lazy_default: false, type: :boolean, desc: "Do front-end lints", aliases: ["-f", "--front-end"]
  class_option :backend, default: false, lazy_default: false, type: :boolean, desc: "Do back-end lints", aliases: ["-b", "--back-end"]
  class_option :statistics, default: false, lazy_default: false, type: :boolean, desc: "Do statistics", aliases: ["-s"]
  class_option :all, default: false, lazy_default: false, type: :boolean, desc: "Do everything", aliases: ["-a"]
  class_option :include, default: [], type: :array, aliases: ["-i"], desc: "Include only specific lints or statistics"
  class_option :exclude, default: [], type: :array, aliases: ["-e"], desc: "Exlude specific lints or statistics"
  class_option :commit, default: 'working', type: :string, banner: "working, last, master, or sha", aliases: ["-c", "--sha"], desc: "Lint by commit or working copy"

  desc "frontend", "Execute all front-end tasks"
  def frontend
    ['scsslint', 'jshint'].each { |e| check_exclude(e) }
  end

  desc "backend", "Lint with all backend lints"
  def backend
    ['rubocop', 'railsbp', 'brakeman'].each { |e| check_exclude(e) }
  end

  desc "statistics", "Run all statistics"
  def statistics
    ['stylestats', 'phantomas', 'wraith'].each { |e| check_exclude(e) }
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
    return Maximus::GitControl.new({ commit: options[:commit], is_dev: true }).lints_and_stats(true)
  end

  # @todo something better than just installing in the global npm file
  # and including phantomjs
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
        path: options[:path],
        is_dev: true
      }
    end

    def scsslint
      Maximus::Scsslint.new(default_options).result
    end

    def jshint
      Maximus::Jshint.new(default_options).result
    end

    def rubocop
      Maximus::Rubocop.new(default_options).result
    end

    def railsbp
      Maximus::Railsbp.new(default_options).result
    end

    def brakeman
      Maximus::Brakeman.new(default_options).result
    end

    def stylestats
      Maximus::Stylestats.new(default_options).result
    end

    def phantomas
      Maximus::Phantomas.new(default_options).result
    end

    def wraith
      Maximus::Wraith.new(default_options).result
    end
  end

  default_task :git
end
