desc "Run all lint tasks for front-end, back-end, statistics, and a bonus compare"
namespace :maximus do

  desc "Execute all front-end tasks"
  task :fe do
    Rake::Task['maximus:fe:all'].invoke
  end
  # alias by longer name
  task :front => :fe

  desc "Execute all back-end tasks"
  task :be do
    Rake::Task['maximus:be:all'].invoke
  end
  # alias by longer name
  task :back => :be

  desc "Execute all statistics tasks"
  task :statistic do
    Rake::Task['maximus:statistic:all'].invoke
  end
  # alias abbreviation
  task :stat => :statistic

  desc "Display lint data from the last commit alone"
  task :compare, :commit do |t, args|
    args.with_defaults(commit: 'last')
    Maximus::GitControl.new({commit: args[:commit]}).lints_and_stats(true)
  end

end

desc "Execute all front-end, back-end and statistic tasks"
task :maximus do
  Rake::Task['maximus:fe:all'].invoke
  Rake::Task['maximus:be:all'].invoke
  Rake::Task['maximus:statistic:all'].invoke
  Rake::Task['maximus:compare'].invoke
end
