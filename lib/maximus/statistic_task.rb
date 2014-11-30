
module Maximus

  class StatisticTask < Statistic

    # @path can be array or string or hash
    # for phantomas and wraith, @path must be string or hash
    # Example: { home: '/', wines: '/wines' }
    # for stylestats, array of paths is suitable
    # Each public method returns complete @@output as Hash
    def initialize(opts = {})
      opts[:is_dev] = true if opts[:is_dev].nil?
      @path = opts[:path]
      opts[:base_url] ||= 'http://localhost:3000'
      @base_url = opts[:base_url]
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

        # For Rails, we only want the name of the compiled asset, because we know it'll live in public/assets. If this isn't Rails, sure, give me the full path because the directory structure is likely unique
        pretty_name = @@is_rails ? file.split('/').pop.gsub(/(-{1}[a-z0-9]{32}*\.{1}){1}/, '.') : file

        puts "#{'stylestats'.color(:green)}: #{pretty_name}\n\n"

        stylestats = `stylestats #{file} --config=#{check_default('stylestats.json')} #{'--type=json' unless @@is_dev}` # include JSON formatter unless we're in dev

        refine_stats(stylestats, pretty_name)

        File.delete(file)
      end

      if @@is_rails
        if @@is_dev
          quietly { Rake::Task['assets:clobber'].invoke } # TODO - review that this may not be best practice, but it's really noisy in the console
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
      @path ||= '/'
      config_file = check_default('phantomas.json')
      @path.is_a?(Hash) ? @path.each { |label, url| phantomas_action(url, config_file) } : phantomas_action(@path, config_file)
      @@output
    end

    # By default checks homepage
    # Requires config to be in config/wraith/history.yaml
    # Copies a new history.yaml if not present
    def wraith

      node_module_exists('phantomjs')
      wraith_exists = File.directory?("#{root_dir}/config/wraith")
      @path ||= { home: '/' }
      # Copy wraith config and run the initial baseline
      # Or, if the config is already there, just run wraith latest
      FileUtils.copy_entry(File.join(File.dirname(__FILE__), "config/wraith"), "#{root_dir}/config/wraith") unless wraith_exists

      edit_yaml("#{root_dir}/config/wraith/history.yaml") do |file|
        file['domains']['base'] = @base_url
        file['paths'] = @path if @path.is_a?(Hash)
      end
      # Set baseline or look for changes
      `wraith #{wraith_exists ? 'latest' : 'history'} config/wraith/history.yaml`
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
        Rails.application.load_tasks

        puts "\n"
        puts 'Compiling assets for stylestats...'.color(:blue)

        if @@is_dev
          quietly { Rake::Task['assets:precompile'].invoke } # TODO - review that this may not be best practice, but it's really noisy in the console
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
    def phantomas_action(url, config_file)
      url = @base_url + url
      # Phantomas doesn't actually skip the skip-modules defined in the config BUT here's to hoping for future support
      phantomas = `phantomas --config=#{config_file} #{url} #{'--reporter=json:no-skip' unless @@is_dev} #{'--colors' if @@is_dev}`
      refine_stats(phantomas, url)
    end

    def wraith_parse

    end

  end
end
