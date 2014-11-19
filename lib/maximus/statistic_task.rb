require 'active_support'
require 'active_support/core_ext/object/blank'

module Maximus

  class StatisticTask < Statistic

    def initialize(opts = {})
      opts[:is_dev] ||= true
      @is_dev = truthy(opts[:is_dev])
      @path = opts[:path]
      @statistic = Statistic.new
      @output = @statistic.output
    end

    def stylestat
      name = __method__.to_s
      node_module_exists("#{name}s")
      searched_files = []
      regex = /(-{1}[a-z0-9]{32}*\.{1}){1}/
      @path ||= is_rails? ? "#{Rails.root}/public/assets/**/*.css" : 'source/assets/**/*'
      config_file = check_default('stylestats-config.json') #Prep for stylestats

      if is_rails?

        puts 'Compiling assets for stylestats...'.color(:blue)

        quietly { Rake::Task['assets:precompile'].invoke }

        Dir.glob(@path).select { |f| File.file? f }.each do |file|
          searched_files << file
        end

      else

        #Load Compass paths if it exists
        if Gem::Specification::find_all_by_name('compass').any?
          require 'compass' unless is_rails?
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

          searched_files << output_file

        end
      end
      searched_files.each do |file|

        if is_rails?
          stylestats = "stylestats #{file} --config=#{config_file} --type=json"
          pretty_name = file.split('/').pop.gsub(regex, '.')
        else
          stylestats = "stylestats #{file.path} --config=#{config_file} --type=json"
          pretty_name = file.path
        end

        puts "Stylestatting #{pretty_name.color(:green)}"

        if @is_dev

          puts `#{stylestats.gsub('--type=json', '')}`

        else

          stats = JSON.parse(`#{stylestats}`)

          @output[:file_path] = pretty_name
          @output[:statistics] = {}

          stats.each do |stat, value|

            @output[:statistics][stat.to_sym] = value

          end

          File.delete(file)

          Remote.new(name, "mercury/new/s/#{name}", @output)

        end
      end

      quietly { Rake::Task['assets:clobber'].invoke } if is_rails?

    end

    def loadreport
      name = __method__.to_s
      node_module_exists('phantomjs')

      file_report_path = File.expand_path("../node/loadreport.js", __FILE__)
    end

  end
end