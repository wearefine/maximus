module Maximus
  # Produce CSS statistics
  # @since 0.1.0
  class Stylestats < Maximus::Statistic

    # Requires node
    # @see Statistic#initialize
    def result

      return if @settings[:stylestats].blank?

      node_module_exists('stylestats')

      if @path.blank?
        @path = is_rails? ? "#{@config.pwd}/public/assets/**/*.css" : "#{@config.pwd}/**/*.css"
      end

      if @path.is_a?(Array)
        css_files = @path
      else
        compile_scss if @settings[:compile_assets]
        css_files = find_css
      end

      css_files.each do |file|

        # For Rails, we only want the name of the compiled asset, because we know it'll live in public/assets.
        #   If this isn't Rails, sure, give me the full path because the directory structure is likely unique
        pretty_name = is_rails? ? file.split('/').pop.gsub(/(-{1}[a-z0-9]{32}*\.{1}){1}/, '.') : file

        puts "#{'stylestats'.color(:green)}: #{pretty_name}\n\n"

        # include JSON formatter unless we're in dev
        stylestats = `stylestats #{file} --config=#{@settings[:stylestats]} #{'--type=json' unless @config.is_dev?}`
        refine(stylestats, pretty_name)

        File.delete(file)
      end

      destroy_assets if @settings[:compile_assets]
      @output

    end


    private

      # Find all CSS files or compile.
      #
      # Uses sprockets if Rails; Sass engine otherwise.
      # Compass is supported
      # @return [#compile_scss_rails, #compile_scss, Array] CSS files
      def compile_scss
        puts "\nCompiling assets for stylestats...".color(:blue)
        if is_rails?

          # Get rake tasks
          Rails.application.load_tasks unless @config.is_dev?
          compile_scss_rails
        else

          load_compass

          compile_scss
        end
      end

      # Load Compass paths if the gem exists
      # @see find_css_files
      # @since 0.1.5
      def load_compass
        if Gem::Specification::find_all_by_name('compass').any?
          require 'compass'
          Compass.sass_engine_options[:load_paths].each do |path|
            Sass.load_paths << path
          end
        end
      end

      # Add directories to load paths
      # @todo This function is here in case older versions of SCSS will need it
      #   because there shouldn't be a need to load paths, but there might be a need
      #   in older versions of SCSS, which should be tested (although the SCSSLint)
      #   dependency may dictate our scss version
      # @since 0.1.5
      def load_scss_load_paths
        Dir.glob(@path).select { |d| File.directory? d}.each do |directory|
          Sass.load_paths << directory
        end
      end

      # Turns scss files into css files with the asset pipeline
      # @see find_css_files
      # @since 0.1.5
      # @return [Array] compiled css files
      def compile_scss_rails
        searched_files = []
        # I'd rather Rake::Task but it's not working in different directories
        if @config.is_dev?
           # @todo review that this may not be best practice, but it's really noisy in the console
          quietly { `rake -f #{@config.pwd}/Rakefile assets:precompile` }
        else
          `rake -f #{@config.pwd}/Rakefile assets:precompile`
        end
      end

      # Turn scss files into css files
      # Skips if the file starts with an underscore
      # @see find_css_files
      # @since 0.1.5
      def compile_scss_normal
        Dir["#{@path}.scss"].select { |f| File.file? f }.each do |file|
          next if File.basename(file).chr == '_'
          scss_file = File.open(file, 'rb') { |f| f.read }

          output_file = File.open( file.split('.').reverse.drop(1).reverse.join('.'), "w" )
          output_file << Sass::Engine.new(scss_file, { syntax: :scss, quiet: true, style: :compressed }).render
          output_file.close
        end
      end

      # Remove all assets created
      # @since 0.1.5
      def destroy_assets

        if is_rails?
          # I'd rather Rake::Task but it's not working in different directories
          if @config.is_dev?
            # @todo review that this may not be best practice, but it's really noisy in the console
            quietly { `rake -f #{@config.pwd}/Rakefile assets:clobber` }
          else
            `rake -f #{@config.pwd}/Rakefile assets:clobber`
          end
        end

      end

      # Find all css files
      # @param path [String] globbed file path
      # @return [Array] paths to compiled CSS files
      def find_css(path = @path)
        Dir.glob(path).select { |f| File.file? f }.map { |file| file }
      end

  end
end
