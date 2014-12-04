module Maximus
  class Stylestats < Maximus::Statistic

    # @path array preferrably absolute paths, but relative should work
    # If stylestatting one file, pass that as an array, i.e. ['/absolute/to/public/assets/application.css']
    def result

      node_module_exists('stylestats')
      @path ||= @@is_rails ? "#{@opts[:root_dir]}/public/assets/**/*.css" : "#{@opts[:root_dir]}source/assets/**/*"

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
        # TODO - I'd rather Rake::Task but it's not working in different directories
        Dir.chdir(@opts[:root_dir]) do
          if @@is_dev
            # TODO - review that this may not be best practice, but it's really noisy in the console
            quietly { `rake assets:clobber` }
          else
            `rake assets:clobber`
          end
        end
      end

      @output

    end


    private

    # Find all CSS files
    # Will compile using sprockets if Rails
    # Will compile using built-in Sass engine otherwise
    # Compass friendly
    # Returns Array of CSS files
    def find_css_files
      searched_files = []

      if @@is_rails
        # Only load tasks if we're not running a rake task
        Rails.application.load_tasks unless @@is_dev

        puts "\n"
        puts 'Compiling assets for stylestats...'.color(:blue)

        # TODO - I'd rather Rake::Task but it's not working in different directories
        Dir.chdir(@opts[:root_dir]) do
          if @@is_dev
             # TODO - review that this may not be best practice, but it's really noisy in the console
            quietly { `rake assets:precompile` }
          else
            `rake assets:precompile`
          end
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

  end
end
