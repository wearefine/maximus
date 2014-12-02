module Maximus
  class Wraith < Maximus::Statistic

    # By default checks homepage
    # Requires config to be in config/wraith/history.yaml
    # Adds a new config/wraith/history.yaml if not present
    # Path should be an Array defined as [{ label: url }]
    # Returns Hash as defined in the wraith_parse method
    def initialize(opts = {})
      super

      node_module_exists('phantomjs', 'brew install')
      @root_config = "#{@opts[:root_dir]}/config/wraith"
      wraith_exists = File.directory?(@root_config)
      @wraith_config_file = "#{@root_config}/history.yaml"

      puts 'Starting visual regression tests with wraith...'.color(:blue)

      # Copy wraith config and run the initial baseline
      # Or, if the config is already there, just run wraith latest
      unless wraith_exists

        FileUtils.copy_entry(File.join(File.dirname(__FILE__), "../config/wraith"), @root_config)
        wraith_yaml_reset
        puts `wraith history #{@wraith_config_file}`

      else

        wraith_yaml_reset

        # If the paths have been updated, call a timeout and run history again
        # TODO - this doesn't work very well. It puts the new shots in the history folder,
        # even with absolute paths. Could be a bug in wraith
        YAML.load_file(@wraith_config_file)['paths'].each do |label, url|
          edit_yaml(@wraith_config_file) do |file|
            unless File.directory?("#{@opts[:root_dir]}/wraith_history_shots/#{label}")
              puts `wraith history #{@wraith_config_file}`
              break
            end
          end
        end

        # Look for changes if it's not the first time
        puts `wraith latest #{@wraith_config_file}`

      end
      wraith_parse
    end


    private

    # Get a diff percentage of all changes by label and screensize
    # { path: { percent_changed: [{ size: percent_diff }] } }
    # Example {:statistics=>{:/=>{:percent_changed=>[{1024=>0.0}, {767=>0.0}, {1024=>0.0}, {767=>0.0}, {1024=>0.0}, {767=>0.0}, {1024=>0.0}, {767=>0.0}] } }}
    # Returns Hash
    def wraith_parse(wraith_config_file = @wraith_config_file)
      paths = YAML.load_file(wraith_config_file)['paths']
      Dir.glob("#{@opts[:root_dir]}/wraith_shots/**/*.txt").select { |f| File.file? f }.each do |file|
        file_object = File.open(file, 'rb')
        orig_label = File.dirname(file).split('/').last
        label = paths[orig_label]
        @output[:statistics][label.to_sym] ||= {}
        @output[:statistics][label.to_sym][:name] = orig_label
        @output[:statistics][label.to_sym][:percent_changed] ||= []
        @output[:statistics][label.to_sym][:percent_changed] << { File.basename(file).split('_')[0].to_i => file_object.read.to_f }
        file_object.close
      end
      @output
    end

    # Update the root domain (docker ports and addresses may change) and set paths as defined in @path
    def wraith_yaml_reset(wraith_config_file = @wraith_config_file)
      edit_yaml(wraith_config_file) do |file|
        unless @@is_dev
          file['snap_file'] = "#{@root_config}/javascript/snap.js"
          file['directory'] = "#{@opts[:root_dir]}/wraith_shots"
          file['history_dir'] = "#{@opts[:root_dir]}/wraith_history_shots"
        end
        # .to_s is for consistency in the yaml, but could likely be removed without causing an error
        fresh_domain = @opts[:port].blank? ? @opts[:base_url].to_s : "#{@opts[:base_url]}:#{@opts[:port]}"
        file['domains']['main'] = fresh_domain
        @path.each { |label, url| file['paths'][label] = url } if @path.is_a?(Hash)
      end
    end

  end
end
