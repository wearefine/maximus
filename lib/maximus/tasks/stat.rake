desc "Run some sweet statistic scripts and post them to the main hub"
namespace :maximus do

  namespace :stat do

    desc "Run stylestats (node required)"
    task :stylestats, :dev, :path do |t, args|
      Maximus::StatisticTask.new({is_dev: args[:dev], path: args[:path], task: t}).stylestats
    end

    desc "Execute all statistics tasks"
    task :all, :dev do |t, args|
      Rake::Task['maximus:fe:stylestats'].invoke(args[:dev])
    end

  end

end