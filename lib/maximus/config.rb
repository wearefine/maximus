require 'active_support'
require 'active_support/core_ext/hash/keys'
require 'open-uri'

module Maximus

  # Global options and configuration
  # @since 0.1.3
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
    # @option opts [String] :domain ('http://localhost') the host - used for Statistics
    # @option opts [String, Integer] :port ('') port number - used for Statistics
    #   and appended to domain. If blank (false, empty string, etc.), will not
    #   append to domain
    # @option opts [String, Array] :file_paths ('') path to files. Accepts glob notation
    # @option opts [Hash] :paths ({home: '/'}) labeled relative path to URLs. Statistics only
    # @option opts [String] :commit accepts sha, "working", "last", or "master".
    # @option opts [String] :config_file ('maximus.yml') path to config file
    # @option opts [Boolean] :compile_assets (true) compile and destroy assets automagically
    # @option opts [String] :framework (nil) accepts 'rails' and 'middleman' (should only be used
    #   when calling Maximus from a Ruby script)
    # @return [#load_config_file #group_families #evaluate_settings] this method is used to set up instance variables
    def initialize(opts = {})

      # Strips from command line
      opts = opts.delete_if { |k, v| v.nil? }

      default_options = YAML.load_file(File.join(File.dirname(__FILE__), 'config', 'maximus.yml')).symbolize_keys
      default_options[:root_dir] = root_dir
      default_options[:port] = 3000 if is_rails?
      default_options[:port] = 4567 if is_middleman?

      root = opts[:root_dir] ? opts[:root_dir] : default_options[:root_dir]

      yaml = default_options.merge load_config_file(opts[:config_file], root)
      @settings = yaml.merge opts

      @settings[:git_log] = false if @settings[:git_log].nil?
      @settings[:git_log] ||= 'log/maximus_git.log' if @settings[:git_log].is_a?(TrueClass)

      @settings[:compile_assets] = true if @settings[:compile_assets].nil?

      @settings[:paths] = split_paths(@settings[:paths]) if @settings[:paths].is_a?(Array)

      group_families

      # Instance variables for Config class only
      @temp_files = {}
      # Override options with any defined in a discovered config file
      evaluate_settings
    end

    # Set global options or generate appropriate config files for lints or statistics
    # @param settings_data [Hash] (@settings) loaded data from the discovered maximus config file
    # @return [Hash] paths to temp config files and static options
    #   These should be deleted with destroy_temp after read and loaded
    def evaluate_settings(settings_data = @settings)
      settings_data.each do |key, value|
        next if value.is_a?(FalseClass)
        value = {} if value.is_a?(TrueClass)

        case key

          when :jshint, :JSHint, :JShint
            value = load_config(value)

            jshint_ignore settings_data[key]
            @settings[:jshint] = temp_it('jshint.json', value.to_json)

          when :scsslint, :SCSSlint
            value = load_config(value)

            @settings[:scsslint] = temp_it('scsslint.yml', value.to_yaml)

          when :rubocop, :Rubocop, :RuboCop
            value = load_config(value)

            @settings[:rubocop] = temp_it('rubocop.yml', value.to_yaml)

          when :brakeman
            @settings[:brakeman] = settings_data[key]

          when :rails_best_practice, :railsbp
            @settings[:railsbp] = settings_data[key]

          when :stylestats, :Stylestats
            value = load_config(value)
            @settings[:stylestats] = temp_it('stylestats.json', value.to_json)

          when :phantomas, :Phantomas
            value = load_config(value)
            @settings[:phantomas] = temp_it('phantomas.json', value.to_json)

          when :wraith, :Wraith
            value = load_config(value)
            evaluate_for_wraith(value)

          # Configuration important to all of maximus
          when :is_dev, :log, :root_dir, :domain, :port, :paths, :commit
            @settings[key] = settings_data[key]
        end
      end

      @settings
    end

    # If output should be returned to console in a pretty display
    # @return [Boolean]
    def is_dev?
      @settings[:is_dev]
    end

    # Grab root directory
    # @since 0.1.6
    # @return [String]
    def working_dir
      @settings[:root_dir]
    end

    # Remove all or one created temporary config file
    # @see temp_it
    # @param filename [String] (nil) file to destroy
    #   If nil, destroy all temp files
    def destroy_temp(filename = nil)
      if filename.nil?
        @temp_files.each { |filename, file| file.unlink }
        @temp_files = {}
      else
        return if @temp_files[filename.to_sym].blank?
        @temp_files[filename.to_sym].unlink
        @temp_files.delete(filename.to_sym)
      end
    end

    # Combine domain with port if necessary
    # @return [String] complete domain/host address
    def domain
      @settings[:port].blank? ? @settings[:domain] : "#{@settings[:domain]}:#{@settings[:port]}"
    end


    protected

      # Look for a maximus config file
      #
      # Checks ./maximus.yml, ./.maximus.yml, ./config/maximus.yml in order.
      #   If there hasn't been a file discovered yet, checks ./config/maximus.yml
      #   and if there still isn't a file, load the default one included with the
      #   maximus gem.
      #
      # @since 0.1.4
      # @param file_path [String]
      # @param root [String] file path to root directory
      # @return @settings [Hash]
      def load_config_file(file_path, root)

        conf_location = if file_path.present? && File.exist?(file_path)
          file_path
        else
          config_exists('.maximus.yml', root) || config_exists('maximus.yml', root) || config_exists('config/maximus.yml', root)
        end

        return {} if conf_location.is_a?(FalseClass)

        yaml = YAML.load_file conf_location
        yaml = {} if yaml.blank?
        yaml.symbolize_keys

      end

      # Allow shorthand to be declared for groups Maximus executions
      #
      # @example disable statistics
      #   @settings[:statistics] = false
      #   set_families('statistics', ['phantomas', 'stylestats', 'wraith'])
      #
      # Sets as Boolean based on whether or not the queried label is `true`
      # @param head_of_house [String] @settings key and group label
      # @param family [Array] group of other @settings keys to be disabled
      # @return [void] modified @settings
      def set_families(head_of_house, family)
        if @settings.key?(head_of_house)
          family.each { |f| @settings[f] ||= @settings[head_of_house].is_a?(TrueClass) }
        end
      end

      # Load config files if filename supplied
      #
      # @param value [Mixed] value from base config file
      # @param [Hash] return blank hash if file not found so
      #   the reset of the process doesn't break
      def load_config(value)
        return value unless value.is_a?(String)

        if value =~ /^http/
          begin open(value)
            YAML.load open(value).read
          rescue
            puts "#{value} not accessible"
            {}
          end
        elsif File.exist?(value)
          YAML.load_file(value)
        else
          puts "#{value} not found"
          {}
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
        file = Tempfile.new([filename, ".#{ext[1]}"]).tap do |f|
          f.rewind
          f.write(data)
          f.close
        end
        @temp_files[ext[0].to_sym] = file
        file.path
      end

      # Accounting for space-separated command line arrays
      # @since 0.1.4
      # @param paths [Array]
      # @return [Hash]
      def split_paths(paths)
        new_paths = {}
        paths.each do |p|
          if p.split('/').length > 1
            new_paths[p.split('/').last.to_s] = p
          else
            new_paths['home'] = '/'
          end
        end
        new_paths
      end

      # Group families of extensions
      # @since 0.1.4
      # @todo the command line options are overriden here and it should be the other way around
      def group_families
        set_families(:lints, [:jshint, :scsslint, :rubocop, :brakeman, :railsbp])
        set_families(:frontend, [:jshint, :scsslint, :phantomas, :stylestats, :wraith])
        set_families(:backend, [:rubocop, :brakeman, :railsbp])
        set_families(:ruby, [:rubocop, :brakeman, :railsbp])
        set_families(:statistics, [:phantomas, :stylestats, :wraith])
        set_families(:all, [:lints, :statistics])
      end

      # Wraith is a complicated gem with significant configuration
      # @see yaml_evaluate, temp_it
      # @param value [Hash] modified data from a wraith config or injected data
      # @param name [String] ('wraith') config file name to write and eventually load
      # @return [String] temp file path
      def wraith_setup(value, name = 'phantomjs')

        if @settings.key?(:urls)
          value['domains'] = @settings[:urls]
        else
          value['domains'] = {}
          # @see #domain
          value['domains']['main'] = domain
        end

        # Set wraith defaults unless they're already defined
        # Wraith requires this screen_width config to be present
        value['screen_widths'] ||= [1280, 1024, 767]
        value['fuzz'] ||= '20%'
        value['threshold'] ||= 0

        value['paths'] = @settings[:paths]
        temp_it("#{name}.yaml", value.to_yaml)
      end

      # Apply wraith defaults/merge existing config
      # @since 0.1.5
      # @see yaml_evaluate
      # @param value [Hash]
      def evaluate_for_wraith(value)
        @settings[:wraith] = {}

        if value.include?('browser')
          value['browser'].each do |browser, browser_value|
            next if browser_value.is_a?(FalseClass)

            # @todo a snap file cannot be set in the config
            snap_file = case browser
              when 'casperjs' then 'casper'
              when 'nojs' then 'nojs'
              else 'snap'
            end

            new_data = {
              'browser' => [{ browser.to_s => browser.to_s }],
              'directory' => "maximus_wraith_#{browser}",
              'history_dir' => "maximus_wraith_history_#{browser}",
              'snap_file' => File.join(File.dirname(__FILE__), "config/wraith/#{snap_file}.js")
            }

            @settings[:wraith][browser.to_sym] = wraith_setup(new_data, "maximus_wraith_#{browser}")
          end
        else
          append_value = {
            'browser' => { 'phantomjs' => 'phantomjs' },
            'directory' => 'maximus_wraith_phantomjs',
            'history_dir' => 'maximus_wraith_history_phantomjs',
            'snap_file' => File.join(File.dirname(__FILE__), "config/wraith/snap.js")
          }
          @settings[:wraith][:phantomjs] = wraith_setup value.merge(append_value)
        end

      end


    private

      # See if a config file exists
      #
      # @see load_config_file
      #
      # This is used exclusively for the load_config_file method
      # @param file [String] file name
      # @param root [String] file path to root directory
      # @return [String, FalseClass] if file is found return the absolute path
      #   otherwise return false so we can keep checking
      def config_exists(file, root)
        present_location = File.join(root, file)
        File.exist?(present_location) ? present_location : false
      end

      # Save jshintignore if available
      # @since 0.1.7
      # @param settings_data_key [Hash]
      # @return updates settings
      def jshint_ignore(settings_data_key)
        return unless settings_data_key.is_a?(Hash) && settings_data_key.key?('jshintignore')

        jshintignore_file = []
        settings_data_key['jshintignore'].each { |i| jshintignore_file << "#{i}\n" }
        @settings[:jshintignore] = temp_it('jshintignore.json', jshintignore_file)
      end

  end
end
