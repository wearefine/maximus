namespace :maximus do
  namespace :be do

    desc "Run rubocop"
    task :rb, [:dev, :path] do |t, args|
      args.with_defaults(
        :dev => false,
        :path => (is_rails? ? "app/" : "*.rb")
      )
      Maximus::LintTask.new({dev: args[:dev], path: args[:path], task: t}).rubocop
    end

    desc "Run rails_best_practices"
    task :railsbp, [:dev, :path] do |t, args|
      args.with_defaults(
        :dev => false,
        :path => "."
      )
      Maximus::LintTask.new({dev: args[:dev], path: args[:path], task: t}).railsbp
    end

    desc "Run brakeman"
    task :brakeman, [:dev, :path] do |t, args|
      args.with_defaults(
        :dev => false,
        :path => Rails.root.to_s
      )
      Maximus::LintTask.new({dev: args[:dev], path: args[:path], task: t}).brakeman
    end

    desc "Execute all back-end tasks"
    task :all, :dev do |t, args|
      Rake::Task['maximus:be:rb'].invoke(args[:dev])
      Rake::Task['maximus:be:railsbp'].invoke(args[:dev]) if is_rails?
      Rake::Task['maximus:be:brakeman'].invoke(args[:dev]) if is_rails?
    end

    task :compare do
      Maximus::VersionControl::GitControl.new.compare
    end

  end

  desc "Execute all back-end tasks"
  task :be, :dev do |t, args|
    Rake::Task['maximus:be:all'].invoke(args[:dev])
  end

end