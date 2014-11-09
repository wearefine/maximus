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
      args.with_defaults(
        :dev => false,
        :path => (is_rails? ? "app/assets/stylesheets/" : "source/assets/stylesheets")
      )
      Maximus::LintTask.new({dev: args[:dev], path: args[:path], task: t}).scsslint
    end

    desc "Run jshint (node required)"
    task :js, :dev, :path do |t, args|
      args.with_defaults(
        :dev => false,
        :path => (is_rails? ? "app/assets/**/*.js" : "source/assets/**")
      )
      Maximus::LintTask.new({dev: args[:dev], path: args[:path], task: t}).jshint
    end

    desc "Run stylestats (node required)"
    task :stylestats, :dev, :path do |t, args|
      args.with_defaults(
        :dev => false,
        :path => (is_rails? ? "#{Rails.root}/public/assets/**/*.css" : 'source/assets/**/*')
      )
      Maximus::StatisticTask.new({dev: args[:dev], path: args[:path], task: t}).stylestats
    end

    desc "Execute all front-end tasks"
    task :all, :dev do |t, args|
      Rake::Task['maximus:fe:scss'].invoke(args[:dev])
      Rake::Task['maximus:fe:js'].invoke(args[:dev])
      Rake::Task['maximus:fe:stylestats'].invoke(args[:dev])
    end

  end

  desc "Execute all front-end tasks"
  task :fe, :dev do |t, args|
    Rake::Task['maximus:fe:all'].invoke(args[:dev])
  end

end

desc "Execute all front-end and back-end tasks"
task :maximus, :dev do |t, args|
  Rake::Task['maximus:fe:all'].invoke(args[:dev])
  Rake::Task['maximus:be:all'].invoke(args[:dev])
end