require 'json'

module Maximus

  # Run lints
  # Returns data as Hash; modified Hash if @from_git,
  class LintTask < Lint

    def initialize(opts = {})
      opts[:is_dev] = true if opts[:is_dev].nil?
      opts[:from_git] = false if opts[:from_git].nil?
      @from_git = opts[:from_git]
      @path = opts[:path]
      @lint = Lint.new(opts[:is_dev])
    end

    # SCSS-Lint
    def scsslint
      @task = __method__.to_s
      @path ||= @@is_rails ? "app/assets/stylesheets" : "source/assets/stylesheets"

      scss = `scss-lint #{@path} -c #{check_default('scsslint.yml')}  --format=JSON`

      files_inspected('scss')
      hash_or_refine(scss)

    end

    # JSHint (requires node module)
    def jshint
      @task = __method__.to_s
      @path ||= @@is_rails ? "app/assets" : "source/assets"

      node_module_exists(@task)

      jshint = `jshint #{@path} --config=#{check_default('jshint.json')} --exclude-path=#{check_default('.jshintignore')} --reporter=#{reporter_path('jshint.js')}`

      files_inspected('js')
      hash_or_refine(jshint)

    end

    # RuboCop
    def rubocop
      @task = __method__.to_s
      @path ||= @@is_rails ? "app" : "*.rb"

      rubo_cli = "rubocop #{@path} --require #{reporter_path('rubocop')} --config #{check_default('rubocop.yml')} --format RuboCop::Formatter::MaximusRuboFormatter"
      rubo_cli += " -R" if @@is_rails
      rubo = `#{rubo_cli}`

      files_inspected('rb', ' ')
      hash_or_refine(rubo)

    end

    # rails_best_practice (requires Rails)
    def railsbp

      return unless @@is_rails

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
          # This crazy gsub grapbs scrubs the absolute path from the filename
          railsbp[file.gsub(Rails.root.to_s, '')[1..-1].to_sym] = errors.map { |o| hash_for_railsbp(o) }
        end
        railsbp = JSON.parse(railsbp.to_json) #don't event ask
      end

      files_inspected('rb', ' ', './')
      hash_or_refine(railsbp, false)

    end

    # Brakeman (requires Rails)
    def brakeman

      return unless @@is_rails

      @task = __method__.to_s
      @path ||= Rails.root.to_s

      tmp = Tempfile.new('brakeman')
      quietly { `brakeman #{@path} -f json -o #{tmp.path} -q` }
      brakeman = tmp.read
      tmp.close

      unless brakeman.blank?
        bjson = JSON.parse(brakeman)
        @@output[:ignored_warnings] = bjson['scan_info']['ignored_warnings']
        @@output[:checks_performed] = bjson['scan_info']['checks_performed']
        @@output[:number_of_controllers] = bjson['scan_info']['number_of_controllers']
        @@output[:number_of_models] = bjson['scan_info']['number_of_models']
        @@output[:number_of_templates] = bjson['scan_info']['number_of_templates']
        @@output[:ruby_version] = bjson['scan_info']['ruby_version']
        @@output[:rails_version] = bjson['scan_info']['rails_version']
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

      files_inspected('rb', ' ', "#{Rails.root.to_s}/")
      hash_or_refine(brakeman, false)

    end

    protected

    # Convert to maximus format
    def hash_for_railsbp(error)
      {
        linter: error['message'].gsub(/\((.*)\)/, '').strip.parameterize('_').camelize,
        severity: 'warning',
        reason: error['message'],
        column: 0,
        line: error['line_number'].to_i
      }
    end

    # Convert to maximus format
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

    # Give git a little more data to help it out
    # If it's from git explicitly, we're looking at line numbers.
    # There's a call in version_control.rb for all lints, and that is not considered 'from_git' because it's not filtering the results and instead taking them all indiscriminately
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


    private

    # List all files inspected
    # Returns Array
    def files_inspected(ext, delimiter = ',', replace = '')
      @@output[:files_inspected] = @path.is_a?(Array) ? @path.split(delimiter) : file_list(@path, ext, replace)
    end

    # Convert export depending on execution origin
    def hash_or_refine(data, parse_JSON = true)
      if parse_JSON
        data = data.blank? ? data : JSON.parse(data) # defend against blank JSON errors
      end
      @from_git ? hash_for_git(data) : @lint.refine(data, @task)
    end

  end
end
