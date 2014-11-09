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

    def railsbp

      return unless is_rails?

      @task = __method__.to_s

      railsbp = `rails_best_practices #{@path} -f json`

      unless railsbp.blank?
        file = File.open('rails_best_practices_output.json')
        rbj = JSON.parse(file.read).railsbp_json.group_by { |s| s['filename'] }
        file.close
        railsbp = {}
        rbj.each do |file, errors|
          railsbp[file.gsub(Rails.root.to_s, '')[1..-1].to_sym] = errors.map { |o| hash_for_railsbp(o) }
        end
        railsbp = railsbp.to_json
        File.delete(file)
      end

      check_empty(railsbp)

      @output[:division] = 'back'
      @output[:files_inspected] = file_count(@path, 'rb')

      @lint.lint_post(@task, @is_dev)

    end

    def brakeman

      return unless is_rails?

      @task = __method__.to_s
      tmp = Tempfile.new('brakeman')
      quietly { `brakeman #{@path} -f json -o #{tmp.path} -q` }
      brakeman = tmp.read
      tmp.close

      unless brakeman.blank?
        bjson = JSON.parse(brakeman)
        brakeman = {}
        ['warnings', 'errors'].each do |type|
          new_brakeman = bjson[type].group_by { |s| s['file'] }
          new_brakeman.each do |file, errors|
            brakeman[file.to_sym] = errors.map { |e| hash_for_brakeman(e, type) }
          end
        end
        brakeman = brakeman.to_json
      end

      tmp.unlink

      check_empty(brakeman)

      @output[:division] = 'back'
      @output[:files_inspected] = file_count(@path, 'rb')

      @lint.lint_post(@task, @is_dev)

    end

    private

    def hash_for_railsbp(error)
      {
        linter: error['message'].parameterize('_').camelize,
        severity: 'warning',
        reason: error['message'],
        column: 0,
        line: error['line_number'].to_i
      }
    end

    def hash_for_brakeman(error, type)
      {
        linter: error['warning_type'],
        severity: type.chomp('s'),
        reason: error['message'],
        column: 0,
        line: error['line'].to_i,
        confidence: error['confidence']
      }
    end

  end
end