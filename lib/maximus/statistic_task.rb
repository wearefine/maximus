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

    def stylestats
      name = __method__.to_s
      node_module_exists(name)
      searched_files = []
      regex = /(-{1}[a-z0-9]{32}*\.{1}){1}/
      @path ||= is_rails? ? "#{Rails.root}/public/assets/**/*.css" : 'source/assets/**/*'
      config_file = check_default('stylestats.json') #Prep for stylestats

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
            @output[:statistics][stat.to_sym] = value # Can I do like a self << thing here?
          end

          File.delete(file)

          Remote.new("mercury/new/s/#{name.chomp('s')}", @output)

        end
      end

      quietly { Rake::Task['assets:clobber'].invoke } if is_rails?

    end

    def phantomas
      node_module_exists('phantomas')
      @path ||= 'http://localhost:3000'
      @path.is_a?(Array) ? @path.each { |u| phantomas_action(u) } : phantomas_action(@path)
    end


    private

    def phantomas_action(url)

      file_report_path = File.expand_path("../node/loadreport.js", __FILE__)
      file_config_path = File.expand_path("../node/config.json", __FILE__)
      config_file = check_default('phantomas.json')
      phantomas = `phantomas --config=#{config_file} #{url} #{'--reporter=json:no-skip' unless @is_dev} #{'--colors' if @is_dev}`

      return puts phantomas if @is_dev # Stop right there unless you mean business

      stats = JSON.parse(phantomas)

      @output[:file_path] = url
      @output[:statistics] = {}
      stats.each do |stat, value|
        @output[:statistics][stat.to_sym] = value # Can I do like a self << thing here?
      end

      Remote.new("mercury/new/s/phantomas", @output)

    end

  end
end