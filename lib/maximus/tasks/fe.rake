require 'rainbow'
require 'rainbow/ext/string'
require 'active_support'
require 'active_support/core_ext/object/blank'
require 'json'

desc "Run some sweet lint scripts and post them to the main hub"
namespace :maximus do

  namespace :fe do

    desc "Run scss-lint" #scss-lint Rake API was challenging
    task :scss, [:dev, :path] do |t, args|
      Maximus::LintTask.new({is_dev: args[:dev], path: args[:path], task: t}).scsslint
    end

    desc "Run jshint (node required)"
    task :js, :dev, :path do |t, args|
      Maximus::LintTask.new({is_dev: args[:dev], path: args[:path], task: t}).jshint
    end

    desc "Execute all front-end tasks"
    task :all, :dev do |t, args|
      Rake::Task['maximus:fe:scss'].invoke(args[:dev])
      Rake::Task['maximus:fe:js'].invoke(args[:dev])
    end

  end

  desc "Execute all front-end tasks"
  task :fe, :dev do |t, args|
    Rake::Task['maximus:fe:all'].invoke(args[:dev])
  end

end

desc "Execute all front-end, back-end and statistic tasks"
task :maximus, :dev do |t, args|
  Rake::Task['maximus:fe:all'].invoke(args[:dev])
  Rake::Task['maximus:be:all'].invoke(args[:dev])
  Rake::Task['maximus:stat:all'].invoke(args[:dev])
end