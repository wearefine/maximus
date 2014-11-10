require 'rainbow'
require 'rainbow/ext/string'
require 'active_support'
require 'active_support/core_ext/object/blank'
require 'json'

desc "Run some sweet statistic scripts and post them to the main hub"
namespace :maximus do

  namespace :stat do

    desc "Run stylestats (node required)"
    task :stylestats, :dev, :path do |t, args|
      Maximus::StatisticTask.new({dev: args[:dev], path: args[:path], task: t}).stylestats
    end

    desc "Execute all statistics tasks"
    task :all, :dev do |t, args|
      Rake::Task['maximus:fe:stylestats'].invoke(args[:dev])
    end

  end

  desc "Execute all statistics tasks"
  task :stat, :dev do |t, args|
    Rake::Task['maximus:stat:all'].invoke(args[:dev])
  end

end