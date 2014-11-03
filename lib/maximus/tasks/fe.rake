require 'rainbow'
require 'rainbow/ext/string'
require 'active_support'
require 'active_support/core_ext/object/blank'
require 'json'

desc "Run some sweet lint scripts and post them to the main hub"

@helper = Maximus::Helper.new

namespace :maximus do
  namespace :fe do

    desc "Run scss-lint" #scss-lint Rake API was challenging
    task :scss, [:dev, :path] do |t, args|
      lint = Maximus::Lint.new
      @output = lint.output

      args.with_defaults(
        :dev => false,
        :path => (@helper.is_rails? ? "app/assets/stylesheets/" : "source/assets/stylesheets")
      )
      is_dev = @helper.truthy(args[:dev])

      config_file = @helper.check_default('scss-lint.yml')

      scss = `scss-lint #{args[:path]} -c #{config_file}  --format=JSON`
      lint.refine(scss, t)
      puts lint.format if is_dev

      @output[:division] = 'front'
      @output[:file_count] = @helper.file_count(args[:path])

      name = 'scss_lint'
      puts lint.after_post(name)

      Maximus::Remote.new(name, "http://localhost:3001/lints/new/#{name}", @output) unless is_dev

    end

    desc "Run jshint (node required)"
    task :js, :dev, :path do |t, args|

      @helper.node_module_exists('jshint')
      lint = Maximus::Lint.new
      @output = lint.output

      args.with_defaults(
        :dev => false,
        :path => (@helper.is_rails? ? "app/assets/**" : "source/assets/**")
      )
      is_dev = @helper.truthy(args[:dev])

      config_file = @helper.check_default('jshint.json')
      exclude_file = @helper.check_default('.jshintignore')

      jshint = `jshint #{args[:path]} --config=#{config_file} --exclude-path=#{exclude_file} --reporter=#{File.expand_path("../../config/jshint-reporter.js", __FILE__)}`

      unless jshint.empty?

          lint.refine(jshint, t)
          puts lint.format if is_dev

      else

        @output[:errors] = 0
        @output[:warnings] = 0

      end

      @output[:division] = 'front'
      @output[:file_count] = @helper.file_count(args[:path])

      name = 'jshint'
      puts lint.after_post(name)

      Maximus::Remote.new(name, "http://localhost:3001/lints/new/#{name}", @output) unless is_dev

    end

    task :stylestats, :dev, :path do |t, args|

      @helper.node_module_exists('stylestats')

      args.with_defaults(
        :dev => false,
        :path => (@helper.is_rails? ? 'app/assets/**/*' : 'source/assets/**/*')
      )
      is_dev = @helper.truthy(args[:dev])

      lint = Maximus::Lint.new
      @output = lint.output

      #Load Compass paths if it exists
      if Gem::Specification::find_all_by_name('compass').any?
        require 'compass' unless @helper.is_rails?
        Compass.sass_engine_options[:load_paths].each do |path|
          Sass.load_paths << path
        end
      end

      #Toggle default looks for rails or middleman
      search_for_scss = args[:path]

      Dir.glob(search_for_scss).select {|f| File.directory? f}.each do |file|
        Sass.load_paths << file
      end

      search_for_scss += ".css.scss"

      #Prep for stylestats
      config_file = @helper.check_default('.stylestatsrc')

      @output[:statistics] = {}
      @output[:statistics][:files] = {} #what am i doing wrong
      Dir[search_for_scss].select { |file| File.file? file }.each do |file|

        scss_file = File.open(file, 'rb') { |f| f.read }

        output_file = File.open( file.split('.').reverse.drop(1).reverse.join('.'), "w" )
        output_file << Sass::Engine.new(scss_file, { syntax: :scss, quiet: true, style: :compressed }).render
        output_file.close


        stylestats = "stylestats #{output_file.path} --config=#{config_file} --type=json"
        puts "Stylestatting #{file.color(:green)}"
        if is_dev

          puts `#{stylestats.gsub('--type=json', '')}`

        else

          stats = JSON.parse(`#{stylestats}`)
          symbol_file = output_file.path.to_sym
          @output[:statistics][:files][symbol_file] = {} #still doing something wrong here
          file_collection = @output[:statistics][:files][symbol_file]

          stats.each do |stat, value|

            file_collection[stat.to_sym] = value

          end

          @output[:raw_data] = stats

          File.delete(output_file)

        end

      end

      @output[:division] = 'front'
      Maximus::Remote.new('stylestats', 'http://localhost:3001/statistics/new/stylestats', @output) unless is_dev

    end

    desc "Get everything done at once"
    task :all => [:scss, :js, :stylestats]

  end
  desc "Argument less task"
  task :fe => 'fe:all'
end
