desc "Run some sweet lint scripts and post them to the main hub"
namespace :maximus do

  desc "Execute all front-end tasks"
  task :fe, :dev do |t, args|
    Rake::Task['maximus:fe:all'].invoke(args[:dev])
  end

  desc "Execute all back-end tasks"
  task :be, :dev do |t, args|
    Rake::Task['maximus:be:all'].invoke(args[:dev])
  end

  desc "Execute all statistics tasks"
  task :stat, :dev do |t, args|
    Rake::Task['maximus:stat:all'].invoke(args[:dev])
  end

  task :compare, :dev do |t, args|
    Maximus::GitControl.new({is_dev: args[:dev]}).lint
  end

end

desc "Execute all front-end, back-end and statistic tasks"
task :maximus, :dev do |t, args|
  Rake::Task['maximus:fe:all'].invoke(args[:dev])
  Rake::Task['maximus:be:all'].invoke(args[:dev])
  Rake::Task['maximus:stat:all'].invoke(args[:dev])
  Rake::Task['maximus:compare'].invoke(args[:dev])
end