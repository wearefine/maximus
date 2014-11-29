desc "Run some sweet lint scripts and post them to the main hub"
namespace :maximus do

  desc "Execute all front-end tasks"
  task :fe do
    Rake::Task['maximus:fe:all'].invoke
  end

  desc "Execute all back-end tasks"
  task :be do
    Rake::Task['maximus:be:all'].invoke
  end

  desc "Execute all statistics tasks"
  task :stat do
    Rake::Task['maximus:stat:all'].invoke
  end

  desc "Display lint data from the last commit alone"
  task :compare do
    Maximus::GitControl.new.lint
  end

end

desc "Execute all front-end, back-end and statistic tasks"
task :maximus do
  Rake::Task['maximus:fe:all'].invoke
  Rake::Task['maximus:be:all'].invoke
  Rake::Task['maximus:stat:all'].invoke
  Rake::Task['maximus:compare'].invoke
end
