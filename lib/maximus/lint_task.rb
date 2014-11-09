
require 'active_support'
require 'active_support/core_ext/object/blank'

module Maximus

  class LintTask < Lint

    def initialize(opts = {})
      @is_dev = truthy(opts[:dev])
      @path = opts[:path]
      @lint = Lint.new
      @output = @lint.output
    end

    def scsslint

      @task = __method__.to_s

      config_file = check_default('scss-lint.yml')

      scss = `scss-lint #{@path} -c #{config_file}  --format=JSON`

      check_empty(scss)

      @output[:division] = 'front'
      @output[:files_inspected] = file_count(@path, 'scss')

      @lint.lint_post(@task, @is_dev)

    end

    def jshint

      @task = __method__.to_s

      node_module_exists(@task)

      config_file = check_default('jshint.json')
      exclude_file = check_default('.jshintignore')

      jshint = `jshint #{@path} --config=#{config_file} --exclude-path=#{exclude_file} --reporter=#{File.expand_path("../config/jshint-reporter.js", __FILE__)}`

      check_empty(jshint)

      @output[:division] = 'front'
      @output[:files_inspected] = file_count(@path, 'js')

      @lint.lint_post(@task, @is_dev)

    end

    def rubocop

      @task = __method__.to_s

      config_file = check_default('rubocop-config.yml')

      rubo_cli = "rubocop #{@path} --require #{File.expand_path("../config/maximus_formatter", __FILE__)} --config #{config_file} --format RuboCop::Formatter::MaximusRuboFormatter"
      rubo_cli += " -R" if is_rails?
      rubo = `#{rubo_cli}`

      check_empty(rubo)

      @output[:division] = 'back'
      @output[:files_inspected] = file_count(@path, 'rb')

      @lint.lint_post(@task, @is_dev)

    end
  end
end