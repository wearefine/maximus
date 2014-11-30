desc "Run some sweet statistic scripts for the front-end"
namespace :maximus do

  namespace :statistic do

    desc "Run stylestats (node required)"
    task :style, :path do |t, args|
      Maximus::StatisticTask.new({path: args[:path], task: t}).stylestats
    end

    desc "Run phantomas (node and phantomjs required)"
    task :phantomas, :path do |t, args|
      Maximus::StatisticTask.new({path: args[:path], task: t}).phantomas
    end

    desc "Run Wraith (phantomjs required)"
    task :wraith, :path do |t, args|
      Maximus::StatisticTask.new({path: args[:path], task: t}).wraith
    end

    desc "Execute all statistics tasks"
    task :all => [:stylestats, :wraith]
    # task :all => [:stylestats, :phantomas] # Just a little too much data

  end

end
