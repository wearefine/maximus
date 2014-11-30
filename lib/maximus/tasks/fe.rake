desc "Run some sweet lint scripts for the front-end"
namespace :maximus do

  namespace :fe do

    desc "Run scss-lint"
    task :scsslint, :path do |t, args|
      Maximus::Lint.new({path: args[:path], task: t}).scsslint
    end
    task :scss, [:path] => :scsslint # alias by extension

    desc "Run jshint (node required)"
    task :jshint, :path do |t, args|
      Maximus::Lint.new({path: args[:path], task: t}).jshint
    end
    task :js, [:path] => :jshint # alias by extension

    desc "Execute all front-end tasks"
    task :all => [:scsslint, :jshint]

  end

  desc "Execute all front-end tasks"
  task :fe do
    Rake::Task['maximus:fe:all'].invoke
  end

end
