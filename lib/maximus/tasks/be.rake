namespace :maximus do
  namespace :be do

    desc "Run rubocop"
    task :rubocop, [:dev, :path] do |t, args|
      Maximus::LintTask.new({is_dev: args[:dev], path: args[:path], task: t}).rubocop
    end

    desc "Run rails_best_practices"
    task :railsbp, [:dev, :path] do |t, args|
      Maximus::LintTask.new({is_dev: args[:dev], path: args[:path], task: t}).railsbp
    end

    desc "Run brakeman"
    task :brakeman, [:dev, :path] do |t, args|
      Maximus::LintTask.new({is_dev: args[:dev], path: args[:path], task: t}).brakeman
    end

    desc "Execute all back-end tasks"
    task :all, :dev do |t, args|
      Rake::Task['maximus:be:rubocop'].invoke(args[:dev])
      Rake::Task['maximus:be:railsbp'].invoke(args[:dev]) if is_rails?
      Rake::Task['maximus:be:brakeman'].invoke(args[:dev]) if is_rails?
    end
    task :rb, [:dev] => :all # alias by extension

  end

end