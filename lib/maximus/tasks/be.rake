desc "Run some sweet lint scripts for the back-end"
namespace :maximus do
  namespace :be do

    desc "Run rubocop"
    task :rubocop, :path do |t, args|
      Maximus::Rubocop.new({ path: args[:path] })
    end

    desc "Run rails_best_practices"
    task :railsbp, :path do |t, args|
      Maximus::Railsbp.new({ path: args[:path] })
    end
    # alias by full name
    task :rails_best_practices => :railsbp

    desc "Run brakeman"
    task :brakeman, :path do |t, args|
      Maximus::Brakeman.new({ path: args[:path] })
    end

    desc "Execute all back-end tasks"
    task :all do
      Rake::Task['maximus:be:rubocop'].invoke
      if defined?(Rails)
        Rake::Task['maximus:be:railsbp'].invoke
        Rake::Task['maximus:be:brakeman'].invoke
      end
    end
    # alias by extension
    task :rb => :all

  end

end
