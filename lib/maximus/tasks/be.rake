require 'rainbow'
require 'rainbow/ext/string'
require 'active_support'
require 'active_support/core_ext/object/blank'

desc "Run some sweet lint scripts and post them to the main hub"
@helper = Maximus::Helper.new

namespace :maximus do
  namespace :be do

    desc "Run rubocop"
    task :rb, [:dev, :path] do |t, args|
      lint = Maximus::Lint.new
      @output = lint.output

      args.with_defaults(
        :dev => false,
        :path => (@helper.is_rails? ? "app/" : "*.rb")
      )
      is_dev = @helper.truthy(args[:dev])

      config_file = @helper.check_default('rubocop-config.yml')

      rubo_cli = "rubocop #{args[:path]} --require #{File.expand_path("../../config/maximus_formatter", __FILE__)} --config #{config_file} --format RuboCop::Formatter::MaximusRuboFormatter"
      rubo_cli += " -R" if @helper.is_rails?
      rubo = `#{rubo_cli}`

      unless rubo.empty?

          lint.refine(rubo, t)
          puts lint.format if is_dev

      else

        @output[:lint_errors] = 0
        @output[:lint_warnings] = 0
        @output[:lint_conventions] = 0
        @output[:lint_refactors] = 0

      end

      @output[:division] = 'back'
      @output[:files_inspected] = @helper.file_count(args[:path], 'rb')

      name = 'rubocop'
      puts lint.after_post(name)

      Maximus::Remote.new(name, "http://localhost:3001/lints/new/#{name}", @output) unless is_dev

    end

    desc "Get everything done at once"
    task :all => [:rubo]

  end
  desc "Argument less task"
  task :be => 'be:all'
end
