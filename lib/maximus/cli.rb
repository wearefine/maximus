require 'thor'

class Maximus::CLI < Thor
  include Thor::Actions
  class_option :path, aliases: ["-p", "-u", "\--url"], default: nil, desc: "Space-separated path(s) to URLs or files"
  class_option :frontend, default: false, lazy_default: false, type: :boolean, desc: "Do front-end lints", aliases: ["-f", "--front-end"]
  class_option :backend, default: false, lazy_default: false, type: :boolean, desc: "Do back-end lints", aliases: ["-b", "--back-end"]
  class_option :statistics, default: false, lazy_default: false, type: :boolean, desc: "Do statistics", aliases: ["-s"]
  class_option :all, default: false, lazy_default: false, type: :boolean, desc: "Do everything", aliases: ["-a"]
  class_option :exclude, default: [], type: :array, aliases: ["-e", "--black-list"], desc: "Exlude specific lints or statistics"
  class_option :include, default: [], type: :array, aliases: ["-i", "--white-list"], desc: "Include only specific lints or statistics"

  desc "scsslint", "Lint with scss-lint"
  def scsslint
    Maximus::Scsslint.new(default_options).result
  end

  desc "jshint", "Lint with jshint (node required)"
  def jshint
    Maximus::Jshint.new(default_options).result
  end

  desc "rubocop", "Lint with rubocop"
  def rubocop
    Maximus::Rubocop.new(default_options).result
  end

  desc "railsbp", "Lint with rails_best_practices"
  def railsbp
    Maximus::Railsbp.new(default_options).result
  end

  desc "brakeman", "Lint with brakeman"
  def brakeman
    Maximus::Brakeman.new(default_options).result
  end

  desc "stylestats", "Run stylestats (node required)"
  def stylestats
    Maximus::Stylestats.new(default_options).result
  end

  desc "phantomas", "Run phantomas (node and phantomjs required)"
  def phantomas
    Maximus::Phantomas.new(default_options).result
  end

  desc "wraith", "Run Wraith (phantomjs required)"
  def wraith
    Maximus::Wraith.new(default_options).result
  end

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
  method_option :commit, default: 'working', type: :string, banner: "working, last, master, or sha", aliases: ["-c", "--sha"], desc: "Lint by commit or working copy"
  def git
    Maximus::GitControl.new({ commit: options[:commit], is_dev: true }).lints_and_stats(true)
  end

  desc "all", "Lint everything"
  def all
    all_tasks = ['frontend', 'backend', 'statistics']
    # If all is defined it overrules everything else
    if options[:all]
      return all_tasks.each { |a| send(a) }
    end
    # If include is blank, run everything
    if options[:include].blank?
      all_tasks.each { |o| check_option(o) }
      # Run front-end lints by default
      if !options[:frontend] && !options[:backend] && !options[:statistics] && !options[:all]
        frontend
      end
    else
      options[:include].each { |i| send(i) }
    end
  end

  # TODO - something better than just installing in whatever gemset
  # and the global npm file
  # and including phantomjs
  desc "install", "Install all dependencies"
  def install
    `npm install -g jshint phantomas stylestats`
    `gem install wraith`
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
  end

  default_task :all
end
