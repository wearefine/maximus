require 'active_support'
require 'active_support/core_ext/object/blank'

module Maximus

  class LintTask < Lint

    def initialize(opts = {})
      opts[:is_dev] ||= false
      opts[:from_git] ||= false
      @from_git = opts[:from_git]
      @is_dev = truthy(opts[:is_dev])
      @path = opts[:path]
      @lint = Lint.new
      @output = @lint.output
    end

    def scsslint
      @task = __method__.to_s
      @path ||= is_rails? ? "app/assets/stylesheets" : "source/assets/stylesheets"

      config_file = check_default('scss-lint.yml')
      scss = `scss-lint #{@path} -c #{config_file}  --format=JSON`

      @output[:files_inspected] = @from_git ? @path.split(',') : file_list(@path, 'scss')

      scss = scss.blank? ? scss : JSON.parse(scss) #defend against blank JSON errors
      return @from_git ? hash_for_git(scss) : refine(scss)

    end

    def jshint
      @task = __method__.to_s
      @path ||= is_rails? ? "app/assets" : "source/assets"

      node_module_exists(@task)

      config_file = check_default('jshint.json')
      exclude_file = check_default('.jshintignore')

      jshint = `jshint #{@path} --config=#{config_file} --exclude-path=#{exclude_file} --reporter=#{File.expand_path("../config/jshint-reporter.js", __FILE__)}`

      @output[:files_inspected] = @from_git ? @path.split(',') : file_list(@path, 'js')

      jshint = jshint.blank? ? jshint : JSON.parse(jshint) #defend against blank JSON errors
      return @from_git ? hash_for_git(jshint) : refine(jshint)

    end

    def rubocop
      @task = __method__.to_s
      @path ||= is_rails? ? "app" : "*.rb"

      config_file = check_default('rubocop-config.yml')

      rubo_cli = "rubocop #{@path} --require #{File.expand_path("../config/maximus_rubo_formatter", __FILE__)} --config #{config_file} --format RuboCop::Formatter::MaximusRuboFormatter"
      rubo_cli += " -R" if is_rails?
      rubo = `#{rubo_cli}`

      @output[:files_inspected] = @from_git ? @path.split(' ') : file_list(@path, 'rb')

      rubo = rubo.blank? ? rubo : JSON.parse(rubo) #defend against blank JSON errors
      return @from_git ? hash_for_git(rubo) : refine(rubo)

    end

    def railsbp

      return unless is_rails?

      @task = __method__.to_s
      @path ||= "."
      tmp = Tempfile.new('railsbp')
      `rails_best_practices #{@path} -f json --output-file #{tmp.path}`
      railsbp = tmp.read
      tmp.close
      tmp.unlink

      unless railsbp.blank?
        rbj = JSON.parse(railsbp).group_by { |s| s['filename'] }
        railsbp = {}
        rbj.each do |file, errors|
          railsbp[file.gsub(Rails.root.to_s, '')[1..-1].to_sym] = errors.map { |o| hash_for_railsbp(o) }
        end
        railsbp = JSON.parse(railsbp.to_json) #don't event ask
      end

      @output[:files_inspected] = @from_git ? @path.split(' ') : file_list(@path, 'rb', './')
      return @from_git ? hash_for_git(railsbp) : refine(railsbp)

    end

    def brakeman

      return unless is_rails?

      @task = __method__.to_s
      @path ||= Rails.root.to_s

      tmp = Tempfile.new('brakeman')
      quietly { `brakeman #{@path} -f json -o #{tmp.path} -q` }
      brakeman = tmp.read
      tmp.close

      unless brakeman.blank?
        bjson = JSON.parse(brakeman)
        @output[:ignored_warnings] = bjson['scan_info']['ignored_warnings']
        @output[:checks_performed] = bjson['scan_info']['checks_performed']
        @output[:number_of_controllers] = bjson['scan_info']['number_of_controllers']
        @output[:number_of_models] = bjson['scan_info']['number_of_models']
        @output[:number_of_templates] = bjson['scan_info']['number_of_templates']
        @output[:ruby_version] = bjson['scan_info']['ruby_version']
        @output[:rails_version] = bjson['scan_info']['rails_version']
        brakeman = {}
        ['warnings', 'errors'].each do |type|
          new_brakeman = bjson[type].group_by { |s| s['file'] }
          new_brakeman.each do |file, errors|
            brakeman[file.to_sym] = errors.map { |e| hash_for_brakeman(e, type) }
          end
        end
        brakeman = JSON.parse(brakeman.to_json) #don't event ask
      end
      tmp.unlink

      @output[:files_inspected] = @from_git ? @path.split(' ') : file_list(@path, 'rb', "#{Rails.root.to_s}/")
      return @from_git ? hash_for_git(brakeman) : refine(brakeman)

    end

    private

    def hash_for_railsbp(error)
      {
        linter: error['message'].gsub(/\((.*)\)/, '').strip.parameterize('_').camelize,
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

    def hash_for_git(data)
      if data.is_a? String
        data = JSON.parse(data) unless data.blank?
      end
      {
        data: data,
        lint: @lint,
        task: @task
      }
    end

  end
end