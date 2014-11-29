desc "Run some sweet lint scripts and post them to the main hub"
namespace :maximus do

  namespace :fe do

    desc "Run scss-lint"
    task :scsslint, [:dev, :path] do |t, args|
      Maximus::LintTask.new({is_dev: args[:dev], path: args[:path], task: t}).scsslint
    end
    task :scss, [:dev, :path] => :scsslint # alias by extension

    desc "Run jshint (node required)"
    task :jshint, :dev, :path do |t, args|
      Maximus::LintTask.new({is_dev: args[:dev], path: args[:path], task: t}).jshint
    end
    task :js, [:dev, :path] => :jshint

    desc "Execute all front-end tasks"
    task :all, :dev do |t, args|
      Rake::Task['maximus:fe:scsslint'].invoke(args[:dev])
      Rake::Task['maximus:fe:jshint'].invoke(args[:dev])
    end

  end

  desc "Execute all front-end tasks"
  task :fe, :dev do |t, args|
    Rake::Task['maximus:fe:all'].invoke(args[:dev])
  end

end