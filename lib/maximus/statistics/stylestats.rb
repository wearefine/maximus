module Maximus
  # @since 0.1.0
  class Stylestats < Maximus::Statistic

    # Produces CSS statistics
    # @see Statistic#initialize
    def result

      return if @settings[:stylestats].blank?

      node_module_exists('stylestats')

      if @path.blank?
        @path = is_rails? ? "#{@settings[:root_dir]}/public/assets/**/*.css" : "#{@settings[:root_dir]}/**/*.css"
      end

      css_files = @path.is_a?(Array) ? @path : find_css_files

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

      destroy_assets
      @output

    end


    private

      # Find all CSS files or compile.
      #
      # Uses sprockets if Rails; Sass engine otherwise.
      # Compass is supported
      # @return [#compile_scss_rails, #compile_scss, Array] CSS files
      def find_css_files
        puts "\nCompiling assets for stylestats...".color(:blue)
        if is_rails?

          # Only load tasks if we're not running a rake task
          Rails.application.load_tasks unless @config.is_dev?
          searched_files = compile_scss_rails

        else

          load_compass

          # Shouldn't need to load paths anymore, but in case this doesn't work
          #   as it should, try the func below
          #
          # Dir.glob(@path).select { |d| File.directory? d}.each do |directory|
          #   Sass.load_paths << directory
          # end

          searched_files = compile_scss
        end
        searched_files
      end

      # Remove all assets created
      # @since 0.1.5
      def destroy_assets

        if is_rails?
          # @todo I'd rather Rake::Task but it's not working in different directories
          Dir.chdir(@settings[:root_dir]) do
            if @config.is_dev?
              # @todo review that this may not be best practice, but it's really noisy in the console
              quietly { `rake assets:clobber` }
            else
              `rake assets:clobber`
            end
          end
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

      # Turns scss files into css files with the asset pipeline
      # @see find_css_files
      # @since 0.1.5
      # @return [Array] compiled css files
      def compile_scss_rails
        searched_files = []
        # @todo I'd rather Rake::Task but it's not working in different directories
        Dir.chdir(@settings[:root_dir]) do
          if @config.is_dev?
             # @todo review that this may not be best practice, but it's really noisy in the console
            quietly { `rake assets:precompile` }
          else
            `rake assets:precompile`
          end
        end

        Dir.glob(@path).select { |f| File.file? f }.each do |file|
          searched_files << file
        end
      end

      # Turns scss files into css files
      # @see find_css_files
      # @since 0.1.5
      # @return [Array] compiled css files
      def compile_scss
        searched_files = []

        @path += ".scss"
        Dir[@path].select { |f| File.file? f }.each do |file|
          # @todo don't compile file if it starts with an underscore
          scss_file = File.open(file, 'rb') { |f| f.read }

          output_file = File.open( file.split('.').reverse.drop(1).reverse.join('.'), "w" )
          output_file << Sass::Engine.new(scss_file, { syntax: :scss, quiet: true, style: :compressed }).render
          output_file.close

          searched_files << output_file.path
        end
        searched_files
      end

  end
end
