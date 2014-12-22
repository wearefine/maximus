module Maximus
  # @since 0.1.2
  # @attr_reader settings [Hash] all the options
  # @attr_reader temp_files [Hash] Filename without extension => path to temp file
  class Config

    include Helper

    attr_reader :settings, :temp_files

    # Global options for all of maximus
    #
    # @param opts [Hash] options passed directly to config
    # @option opts [Boolean] :is_dev (false) whether or not the class was initialized from the command line
    # @option opts [String, Boolean, nil] :log ('log/maximus_git.log') path to log file
    #   If not set, logger outputs to STDOUT
    # @option opts [String, Boolean] :git_log (false) path to log file or don't log
    #   The git gem is very noisey
    # @option opts [String] :root_dir base directory
    # @option opts [String] :domain ('http://localhost:3000') the host - used for Statistics
    # @option opts [String, Integer] :port ('') port number - used for Statistics
    #   and appended to domain. If blank (false, empty string, etc.), will not
    #   append to domain
    # @option opts [String, Array] :file_paths ('') path to files. Accepts glob notation
    # @option opts [Hash] :paths ({home: '/'}) labeled relative path to URLs. Statistics only
    # @option opts [String] :commit accepts sha, "working", "last", or "master".
    # @option opts [String] :config_file ('maximus.yml') path to config file
    # @return [void] this method is used to set up instance variables
    def initialize(opts = {})
      opts[:is_dev] ||= false

      # Only set log file if it's set to true.
      #   Otherwise, allow it to be nil or a path
      opts[:log] = 'log/maximus.log' if opts[:log].is_a?(TrueClass)

      opts[:git_log] = false if opts[:git_log].nil?
      opts[:git_log] = 'log/maximus_git.log' if opts[:git_log].is_a?(TrueClass)

      # @see Helper#root_dir
      opts[:root_dir] ||= root_dir
      opts[:domain] ||= 'http://localhost'
      opts[:port] ||= is_rails? ? 3000 : ''
      opts[:paths] ||= { 'home' => '/' }

      # Accounting for space-separated command line arrays
      if opts[:paths].is_a?(Array)
        new_paths = {}
        opts[:paths].each do |p|
          if p.split('/').length > 1
            new_paths[p.split('/').last.to_s] = p
          else
            new_paths['home'] = '/'
          end
        end
        opts[:paths] = new_paths
      end

      # What we're really interested in
      @settings = opts

      # Instance variables for Config class only
      @temp_files = {}

      conf_location = (opts[:config_file] && File.exist?(opts[:config_file])) ? opts[:config] : find_config

      @yaml = YAML.load_file(conf_location)

      # Match defaults
      @yaml['domain'] ||= @settings[:domain]
      @yaml['paths'] ||= @settings[:paths]
      @yaml['port'] ||= @settings[:port]
      set_families('lints', ['jshint', 'scsslint', 'rubocop', 'brakeman', 'railsbp'])
      set_families('statistics', ['phantomas', 'stylestats', 'wraith'])

      # Override options with any defined in a discovered config file
      evaluate_yaml
    end

    # Set global options or generate appropriate config files for lints or statistics
    #
    # @param yaml_data [Hash] (@yaml) loaded data from the discovered maximus config file
    # @return [Hash] paths to temp config files and static options
    #   These should be deleted with destroy_temp after read and loaded
    def evaluate_yaml(yaml_data = @yaml)
      yaml_data.each do |key, value|
        unless value.is_a?(FalseClass)
          value = {} if value.is_a?(TrueClass)

          case key

            when 'jshint', 'JSHint', 'JShint'

              # @todo DRY this up, but can't call it at the start because of the
              #   global config variables (last when statement in this switch)
              value = load_config(value)

              if yaml_data[key].is_a?(Hash) && yaml_data[key].has_key?['ignore']
                jshintignore_file = []
                yaml_data[key]['ignore'].each { |i| jshintignore_file << "#{i}\n" }
                @settings[:jshintignore] = temp_it('jshintignore.json', jshintignore_file)
              end
              @settings[:jshint] = temp_it('jshint.json', value.to_json)

            when 'scsslint', 'scss-lint', 'SCSSlint'
              value = load_config(value)

              @settings[:scsslint] = temp_it('scsslint.yml', value.to_yaml)

            when 'rubocop', 'Rubocop', 'RuboCop'
              value = load_config(value)

              @settings[:rubocop] = temp_it('rubocop.yml', value.to_yaml)

            when 'brakeman'
              @settings[:brakeman] = yaml_data[key]

            when 'rails_best_practice', 'railsbp'
              @settings[:railsbp] = yaml_data[key]

            when 'stylestats', 'Stylestats'
              value = load_config(value)
              @settings[:stylestats] = temp_it('stylestats.json', value.to_json)

            when 'phantomas', 'Phantomas'
              value = load_config(value)
              @settings[:phantomas] = temp_it('phantomas.json', value.to_json)

            when 'wraith', 'Wraith'
              value = load_config(value)

              @settings[:wraith] = {}
              if value.include?('browser')
                value['browser'].each do |browser, browser_value|
                  unless browser_value.is_a?(FalseClass)
                    new_data = {}
                    new_data['browser'] = []
                    new_data['browser'] << { browser.to_s => browser.to_s }

                    # Regardless of what's in the config, override with maximus,
                    #   predictable namespacing
                    new_data['directory'] = "maximus_wraith_#{browser}"
                    new_data['history_dir'] = "maximus_wraith_history_#{browser}"

                    # @todo a snap file cannot be set in the config
                    snap_file = case browser
                      when 'casperjs' then 'casper'
                      when 'nojs' then 'nojs'
                      else 'snap'
                    end
                    new_data['snap_file'] = File.join(File.dirname(__FILE__), "config/wraith/#{snap_file}.js")

                    @settings[:wraith][browser.to_sym] = wraith_setup(new_data, "wraith_#{browser}")
                  end
                end
              else
                value['browser'] = { 'phantomjs' => 'phantomjs' }
                value['directory'] = 'maximus_wraith_phantomjs'
                value['history_dir'] = 'maximus_wraith_history_phantomjs'
                value['snap_file'] = File.join(File.dirname(__FILE__), "config/wraith/snap.js")
                @settings[:wraith][:phantomjs] = wraith_setup(value)
              end

            # Configuration important to all of maximus
            when 'is_dev', 'log', 'root_dir', 'domain', 'port', 'paths', 'commit'
              @settings[key.to_sym] = yaml_data[key]
          end
        end
      end

      # Finally, we're done
      @settings
    end

    # @return [Boolean]
    def is_dev?
      @settings[:is_dev]
    end

    # Defines base logger
    #
    # @param out [String, STDOUT] location for logging
    #   Accepts file path
    # @return [Logger] self.log
    def log
      out = @settings[:log] || STDOUT
      @log ||= Logger.new(out)
      @log.level ||= Logger::INFO
      @log
    end

    # Remove all or one created temporary config file
    #
    # @see #temp_it
    # @see #yaml_evaluate
    #
    # @param filename [String] (nil) file to destroy
    #   If nil, destroy all temp files
    # @return [void]
    def destroy_temp(filename = nil)
      return if @temp_files[filename.to_sym].blank?
      if filename.nil?
        @temp_files.each { |filename, file| file.unlink }
        @temp_files = {}
      else
        @temp_files[filename.to_sym].unlink
        @temp_files.delete(filename.to_sym)
      end
    end

    # Combine domain with port if necessary
    #
    # @return [String] complete domain/host address
    def domain
      (!@settings[:port].blank? || @settings[:domain].include?(':')) ? "#{@settings[:domain]}:#{@settings[:port]}" : @settings[:domain]
    end


    private

    # Allow shorthand to be declared for groups Maximus executions
    #
    # @example disable statistics
    #   @yaml['statistics'] = false
    #   set_families('statistics', ['phantomas', 'stylestats', 'wraith'])
    #
    # @param head_of_house [String] @yaml key and group label
    # @param family [Array] group of other @yaml keys to be disabled
    # @return [void] modified @yaml
    def set_families(head_of_house, family)
      if @yaml.has_key?(head_of_house)
        family.each { |f| @yaml[f] = @yaml[head_of_house].is_a?(TrueClass) }
      end
    end

    # Load config files if filename supplied
    #
    # @param value [Mixed] value from base config file
    # @param [Hash] return blank hash if file not found so
    #   the reset of the process doesn't break
    def load_config(value)
      return value unless value.is_a?(String)
      if File.exist?(value)
        return YAML.load_file(value)
      else
        puts "#{value} not found"
        return {}
      end
    end

    # Create a temp file with config data
    #
    # Stores all temp files in @temp_files or self.temp_files
    #   In Hash with filename minus extension as the key.
    #
    # @param filename [String] the preferred name/identifier of the file
    # @param data [Mixed] config data important to each lint or statistic
    # @return [String] absolute path to new config file
    def temp_it(filename, data)
      ext = filename.split('.')
      file = Tempfile.new([filename, ".#{ext[1]}"])
      file.write(data)
      file.close
      @temp_files[ext[0].to_sym] = file
      file.path
    end

    # Look for a maximus config file
    #
    # Checks ./maximus.yml, ./maximus.yaml, ./config/maximus.yaml in order.
    #   If there hasn't been a file discovered yet, checks ./config/maximus.yml
    #   and if there still isn't a file, load the default one included with the
    #   maximus gem.
    #
    # @return [String] absolute path to config file
    def find_config
      config_exists('maximus.yml') || config_exists('maximus.yaml') || config_exists('config/maximus.yaml') || check_default_config_path('maximus.yml')
    end

    # See if a config file exists
    #
    # @see #find_config
    #
    # This is used exclusively for the find_config method
    # @param file [String] file name
    # @return [String, FalseClass] if file is found return the absolute path
    #   otherwise return false so we can keep checking
    def config_exists(file)
      File.exist?(File.join(File.dirname(__FILE__), file)) ? File.join(File.dirname(__FILE__), file) : false
    end

    # Wraith is a complicated gem with significant configuration
    #
    # @see #yaml_evaluate
    # @see #temp_it
    #
    # @param value [Hash] modified data from a wraith config or injected data
    # @param name [String] ('wraith') config file name to write and eventually load
    # @return [String] temp file path
    def wraith_setup(value, name = 'phantomjs')

      if @yaml.include?('urls')
        value['domains'] = yaml_data['urls']
      else
        value['domains'] = {}
        # @see #domain
        value['domains']['main'] = domain
      end

      # Wraith requires this screen_width config to be present
      value['screen_widths'] ||= [767, 1024, 1280]

      value['paths'] = @yaml['paths']

      # Wraith requires config files have .yaml extensions
      # https://github.com/BBC-News/wraith/blob/2aff771eba01b76e61600cccb2113869bfe16479/lib/wraith/wraith.rb
      file = Tempfile.new([name, '.yaml'])
      file.write(value.to_yaml)
      file.close
      file.path
    end

  end
end