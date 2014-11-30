
module Maximus

  class StatisticTask < Statistic

    # @path can be array or string or hash
    # for phantomas and wraith, @path must be string or hash
    # Example: { home: '/', wines: '/wines' }
    # for stylestats, array of paths is suitable
    # Each public method returns complete @@output as Hash
    def initialize(opts = {})
      opts[:root_dir] ||= root_dir
      opts[:port] ||= ''
      opts[:is_dev] = true if opts[:is_dev].nil?
      opts[:base_url] ||= 'http://localhost:3000'
      @opts = opts
      @path = opts[:path]
      @statistic = Statistic.new(opts[:is_dev])
    end

    # @path array preferrably absolute paths, but relative should work
    # If stylestatting one file, pass that as an array, i.e. ['/absolute/to/public/assets/application.css']
    # This saves creating an extra method a la the phantomas double methods
    # Phantomas is done this way because passing a single, unique, undigested URL will be way more common than a .css path
    def stylestats
      node_module_exists('stylestats')
      @path ||= @@is_rails ? "#{Rails.root}/public/assets/**/*.css" : 'source/assets/**/*'

      css_files = @path.is_a?(Array) ? @path : find_css_files

      css_files.each do |file|

        # For Rails, we only want the name of the compiled asset, because we know it'll live in public/assets.
        # If this isn't Rails, sure, give me the full path because the directory structure is likely unique
        pretty_name = @@is_rails ? file.split('/').pop.gsub(/(-{1}[a-z0-9]{32}*\.{1}){1}/, '.') : file

        puts "#{'stylestats'.color(:green)}: #{pretty_name}\n\n"

        # include JSON formatter unless we're in dev
        stylestats = `stylestats #{file} --config=#{check_default('stylestats.json')} #{'--type=json' unless @@is_dev}`

        refine_stats(stylestats, pretty_name)

        File.delete(file)
      end

      if @@is_rails
        if @@is_dev
          # TODO - review that this may not be best practice, but it's really noisy in the console
          quietly { Rake::Task['assets:clobber'].invoke }
        else
          Rake::Task['assets:clobber'].invoke
        end
      end

      @@output

    end

    # @path can be array or string of URLS. Include http://
    # By default, checks homepage
    def phantomas
      node_module_exists('phantomas')

      @path ||= YAML.load_file(check_default('phantomas_urls.yaml'))
      puts 'Analyzing with phantomas...'.color(:blue)
      # Phantomas doesn't actually skip the skip-modules defined in the config BUT here's to hoping for future support
      phantomas_cli = "phantomas --config=#{check_default('phantomas.json')} "
      phantomas_cli += @@is_dev ? '--colors' : '--reporter=json:no-skip'
      phantomas_cli += " --proxy=#{@opts[:base_url]}:#{@opts[:port]}" unless @opts[:port].blank?
      @path.is_a?(Hash) ? @path.each { |label, url| phantomas_action(url, phantomas_cli) } : phantomas_action(@path, phantomas_cli)
      @@output
    end

    # By default checks homepage
    # Requires config to be in config/wraith/history.yaml
    # Adds a new config/wraith/history.yaml if not present
    # Returns Hash as defined in the wraith_parse method
    def wraith

      node_module_exists('phantomjs')
      @root_config = @@is_dev ? 'config/wraith' : "#{@opts[:root_dir]}/config/wraith"
      wraith_exists = File.directory?(@root_config)
      @wraith_config_file = "#{@root_config}/history.yaml"

      puts 'Starting visual regression tests with wraith...'.color(:blue)

      # Copy wraith config and run the initial baseline
      # Or, if the config is already there, just run wraith latest
      unless wraith_exists

        FileUtils.copy_entry(File.join(File.dirname(__FILE__), "config/wraith"), @root_config)
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


    protected

    # Find all CSS files
    # Will compile using sprockets if Rails
    # Will compile using built-in Sass engine otherwise
    # Compass friendly
    # Returns Array of CSS files
    def find_css_files
      searched_files = []

      if @@is_rails
        # Only load tasks if we're not running a rake task
        # http://stackoverflow.com/questions/2467208/how-can-i-tell-if-rails-code-is-being-run-via-rake-or-script-generate
        Rails.application.load_tasks unless File.basename($0) == 'rake'

        puts "\n"
        puts 'Compiling assets for stylestats...'.color(:blue)

        if @@is_dev
           # TODO - review that this may not be best practice, but it's really noisy in the console
          quietly { Rake::Task['assets:precompile'].invoke }
        else
          Rake::Task['assets:precompile'].invoke
        end

        Dir.glob(@path).select { |f| File.file? f }.each do |file|
          searched_files << file
        end

      else

        # Load Compass paths if it exists
        if Gem::Specification::find_all_by_name('compass').any?
          require 'compass'
          Compass.sass_engine_options[:load_paths].each do |path|
            Sass.load_paths << path
          end
        end

        Dir.glob(@path).select { |d| File.directory? d}.each do |directory|
          Sass.load_paths << directory
        end

        @path += ".css.scss"

        Dir[@path].select { |f| File.file? f }.each do |file|

          scss_file = File.open(file, 'rb') { |f| f.read }

          output_file = File.open( file.split('.').reverse.drop(1).reverse.join('.'), "w" )
          output_file << Sass::Engine.new(scss_file, { syntax: :scss, quiet: true, style: :compressed }).render
          output_file.close

          searched_files << output_file.path

        end
      end
      searched_files
    end


    private

    # Organize stat output on the @@output variable
    # Adds @@output[:statistics][:filepath] with all statistic data
    def phantomas_action(url, phantomas_cli)
      puts "Phantomas on #{@opts[:base_url] + url}".color(:green)
      phantomas = `#{phantomas_cli} #{@opts[:base_url] + url}`
      refine_stats(phantomas, url)
    end

    # Get a diff percentage of all changes by label and screensize
    # { path: { percent_changed: [{ size: percent_diff }] } }
    # Example {:statistics=>{:/=>{:percent_changed=>[{1024=>0.0}, {767=>0.0}, {1024=>0.0}, {767=>0.0}, {1024=>0.0}, {767=>0.0}, {1024=>0.0}, {767=>0.0}] } }}
    # Returns Hash
    def wraith_parse(wraith_config_file = @wraith_config_file)
      paths = YAML.load_file(wraith_config_file)['paths']
      Dir.glob("#{@opts[:root_dir]}/wraith_shots/**/*.txt").select { |f| File.file? f }.each do |file|
        file_object = File.open(file, 'rb')
        label = File.dirname(file).split('/').last
        label = paths[label]
        @@output[:statistics][label.to_sym] ||= {}
        @@output[:statistics][label.to_sym][:percent_changed] ||= []
        @@output[:statistics][label.to_sym][:percent_changed] << { File.basename(file).split('_')[0].to_i => file_object.read.to_f }
        file_object.close
      end
      @@output
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
