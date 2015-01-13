module Maximus
  # @since 0.1.0
  class Wraith < Maximus::Statistic

    # Generates screenshots for visual regression testing
    # @see Statistic#initialize
    def result

      return if @settings[:wraith].blank?

      node_module_exists('phantomjs', 'brew install')

      puts 'Starting visual regression tests with wraith...'.color(:blue)

      # Run history or latest depending on the existence of a history directory as defined
      #   in each wraith config file.
      #
      # @todo this doesn't work very well. It puts the new shots in the history folder,
      #   even with absolute paths. Could be a bug in wraith
      #
      # @yieldparam browser [String] headless browser name
      # @yieldparam configpath [String] path to temp config file (see Config#wraith_setup)
      @settings[:wraith].each do |browser, configpath|
        return unless File.file?(configpath) # prevents abortive YAML error if it can't find the file
        wraith_yaml = YAML.load_file(configpath)
        if File.directory?("#{@settings[:root_dir]}/#{wraith_yaml['history_dir']}")
          puts `wraith latest #{configpath}`
          # Reset history dir
          puts `rm -rf #{@settings[:root_dir]}/#{wraith_yaml['history_dir']}`
        end
        wraith_parse browser
        puts `wraith history #{configpath}`
      end
      @output

    end


    private

      # Get a diff percentage of all changes by label and screensize
      #
      # @example { :statistics => { "/" => { :browser=>"phantomjs", :name=>"home", :percent_changed=>{ 1024=>2.1, 1280=>1.8, 767=>3.4 } } } }
      # @param browser [String] headless browser used to generate the gallery
      # @return [Hash] { path: { browser, path_label, percent_changed: { size: percent_diff ] } }
      def wraith_parse(browser)
        Dir.glob("#{@settings[:root_dir]}/maximus_wraith_#{browser}/**/*.txt").select { |f| File.file? f }.each do |file|
          file_object = File.open(file, 'rb')
          orig_label = File.dirname(file).split('/').last
          label = @settings[:paths][orig_label]
          @output[:statistics][label.to_s] ||= {}
          browser_output = @output[:statistics][label.to_s]
          browser_output ||= {}
          browser_output[:browser] = browser.to_s
          browser_output[:name] = orig_label
          browser_output[:percent_changed] ||= {}
          browser_output[:percent_changed][File.basename(file).split('_')[0].to_i] = file_object.read.to_f
          file_object.close
        end
        @output
      end

  end
end
