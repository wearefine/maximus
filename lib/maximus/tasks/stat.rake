desc "Run some sweet statistic scripts for the front-end"
namespace :maximus do

  namespace :stat do

    desc "Run stylestats (node required)"
    task :stylestats, :path do |t, args|
      Maximus::StatisticTask.new({path: args[:path], task: t}).stylestats
    end

    desc "Run phantomas (node and phantomjs required)"
    task :phantomas, :path do |t, args|
      Maximus::StatisticTask.new({path: args[:path], task: t}).phantomas
    end

    desc "Execute all statistics tasks"
    task :all => [:stylestats]
    # task :all => [:stylestats, :phantomas] # Just a little too much data

  end

end
