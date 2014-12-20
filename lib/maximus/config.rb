module Maximus
  class Config

    def initialize
      @configs = {}
      @temp_files = []
      @yaml = YAML.load_file(find_config)
    end

    # Generate appropriate config files for lints or statistics
    #
    # @param yaml_data [Hash] loaded data from the discovered maximus config file
    # @return [Hash] paths to temp config files
    #   These should be deleted with destroy_all_temp after read and loaded
    def evaluate_yaml(yaml_data = yaml_data)
      yaml_data.each do |lint, lint_data|
        unless lint_data.is_a?(FalseClass)
          lint_data = {} if lint_data.is_a?(TrueClass)
          case lint

            when 'jshint', 'JSHint', 'JShint'
              if yaml_data[lint]['ignore']
                jshintignore_file = []
                yaml_data[lint]['ignore'].each { |i| jshintignore_file << "#{i}\n" }
                @configs[:jshintignore] = temp_it('.jshintignore', jshintignore_file)
              end
              @configs[:jshint] = temp_it('jshint.json', lint_data.to_json)

            when 'scsslint', 'scss-lint', 'SCSSLint'
              lint_data['format'] = 'JSON'
              @configs[:scsslint] = temp_it('scsslint.yml', lint_data.to_yaml)

            when 'rubocop'
              @configs[:rubocop] = temp_it('rubocop.yml', lint_data.to_yaml)

            when 'stylestats'
              @configs[:stylestats] = temp_it('stylestats.json', lint_data.to_json)

            when 'phantomas'
              @configs[:phantomas] = temp_it('phantomas.json', lint_data.to_json)

            when 'wraith'
              @configs[:wraith] = {}
              if lint_data.include?('browser')
                lint_data['browser'].each do |browser, browser_value|
                  unless browser_value.is_a?(FalseClass)
                    new_data = {}
                    new_data['browser'] = []
                    new_data['browser'] << { browser.to_sym => browser.to_s }

                    new_data['directory'] = "maximus_#{browser}_wraith"
                    new_data['history_dir'] = "maximus_#{browser}_wraith_history"
                    puts browser
                    if browser == 'casperjs'
                      new_data['snap_file'] = File.join(File.dirname(__FILE__), "config/wraith/casper.js")
                    elsif browser == 'nojs'
                      new_data['snap_file'] = File.join(File.dirname(__FILE__), "config/wraith/nojs.js")
                    elsif browser == 'phantomjs'
                      new_data['directory'] = "maximus_wraith"
                      new_data['history_dir'] = "maximus_wraith_history"
                      new_data['snap_file'] = File.join(File.dirname(__FILE__), "config/wraith/snap.js")
                    end

                    @configs[:wraith] << wraith_setup(new_data, "wraith_#{browser}")
                  end
                end
              else
                lint_data['browser'] = []
                lint_data['browser'] << { phantomjs: 'phantomjs' }
                lint_data['directory'] = 'maximus_wraith'
                lint_data['history_dir'] = 'maximus_wraith_history'
                lint_data['snap_file'] = File.join(File.dirname(__FILE__), "config/wraith/snap.js")
                @configs[:wraith] << wraith_setup(lint_data)
              end

            # Configuration important to all of maximus
            when 'base_url', 'paths', 'root_dir'
              @configs[lint.to_sym] = yaml_data[lint]
          end
        end
      end

      # Finally, we're done
      @configs
    end

    # Remove all created temporary config files
    #
    # @see Config#temp_it
    # @see Config#yaml_evaluate
    # @return [void]
    def destroy_all_temp
      @temp_files.each do |temp|
        temp.close
        temp.unlink
      end
    end

    private

    # Look for a maximus config file
    #
    # Checks ./maximus.yml, ./maximus.yaml, ./config/maximus.yaml in order.
    #   If there hasn't been a file discovered yet, checks ./config/maximus.yml
    #   and if there still isn't a file, load the default one included with the
    #   maximus gem.
    # @return [String] absolute path to config file
    def find_config
      config_exists('maximus.yml') || config_exists('maximus.yaml') || config_exists('config/maximus.yaml') || check_default('maximus.yml')
    end

    # See if a config file exists
    #
    # @see Config#find_config
    #
    # This is used exclusively for the find_config method
    # @param file [String] file name
    # @return [String, FalseClass] if file is found return the absolute path
    #   otherwise return false so we can keep checking
    def config_exists(file)
      File.exist?(File.join(File.dirname(__FILE__), file)) ? File.join(File.dirname(__FILE__), file) : false
    end

    # Create a temp file with config data
    #
    # @param filename [String] the preferred name/identifier of the file
    # @param data [Mixed] config data important to each lint or statistic
    # @return [String] absolute path to new config file
    def temp_it(filename, data)
      file = Tempfile.new(filename)
      file.write(data)
      @temp_files << file
      file.path
    end

    # Wraith is a complicated gem with significant configuration
    #
    # @see Config#yaml_evaluate
    # @see Config#temp_if
    #
    # @param lint_data [Hash] modified data from a wraith config or injected data
    # @param name [String] config file name to write and eventually load
    # @return [String] temp file path
    def wraith_setup(lint_data, name = 'wraith')
      if yaml_data.include?('urls')
        lint_data['domains'] = yaml_data['urls']
      else
        lint_data['domains'] = {}
        lint_data['domains']['main'] = yaml_data['base_url'] ? yaml_data['base_url'] : 'http://localhost:3000'
      end
      if yaml_data.include?('paths')
        lint_data['paths'] = yaml_data['paths']
      else
        lint_data['paths'] = {}
        lint_data['paths']['home'] = '/'
      end
      temp_it("#{name}.yml", lint_data.to_yaml)
    end

  end
end