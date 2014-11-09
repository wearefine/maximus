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

    desc "Execute all back-end tasks"
    task :all, :dev do |t, args|
      Rake::Task['maximus:be:rb'].invoke(args[:dev])
    end

  end

  desc "Execute all back-end tasks"
  task :be, :dev do |t, args|
    Rake::Task['maximus:be:all'].invoke(args[:dev])
  end

end