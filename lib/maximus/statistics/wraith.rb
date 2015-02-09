module Maximus
  # Generates screenshots for visual regression testing
  # @since 0.1.0
  class Wraith < Maximus::Statistic

    # Runs Wraith through command line
    # WARNING: If you call this class from a script,
    #   you should delete the images generated after they've been
    #   created.
    # @example removing images after run
    #   dest = '/desired/root/directory'
    #   wraith_pics = Maximus::Wraith.new.result
    #   wraith_pics.each do |path_label, data|
    #     data[:images].each do |image|
    #       moved_image = "#{dest}/#{File.basename(image)}"
    #       FileUtils.mv image, moved_image, force: true
    #     end
    #   end
    #
    # @see Statistic#initialize
    def result

      return if @settings[:wraith].blank?

      node_module_exists('phantomjs', 'brew install')

      puts 'Starting visual regression tests with wraith...'.color(:blue)

      # Run history or latest depending on the existence of a history directory as defined
      #   in each wraith config file.
      # @yieldparam browser [String] headless browser name
      # @yieldparam configpath [String] path to temp config file (see Config#wraith_setup)
      @settings[:wraith].each do |browser, configpath|
        next unless File.file?(configpath) # prevents abortive YAML error if it can't find the file
        wraith_yaml = YAML.load_file(configpath)
        if File.directory?("#{@config.working_dir}/#{wraith_yaml['history_dir']}")
          puts `wraith latest #{configpath}`

          # Reset history dir
          # It puts the new shots in the history folder, even with absolute paths in the config.
          #   Could be a bug in wraith.
          FileUtils.remove_dir("#{@config.working_dir}/#{wraith_yaml['history_dir']}")
        end
        wraith_parse browser unless @config.is_dev?
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
        Dir.glob("#{@config.working_dir}/maximus_wraith_#{browser}/**/*").select { |f| File.file? f }.each do |file|
          extension = File.extname(file)
          next unless extension == '.png' || extension == '.txt'

          orig_label = File.dirname(file).split('/').last

          path = @settings[:paths][orig_label].to_s

          @output[:statistics][path] = {
            browser: browser.to_s,
            name: orig_label
          } if @output[:statistics][path].blank?

          browser_output = @output[:statistics][path]

          if extension == '.txt'
            browser_output = wraith_percentage(file, browser_output)
          else
            browser_output[:images] ||= []
            browser_output[:images] << wraith_image(file)
          end

        end
        @output
      end

      # Grab the percentage change from previous snapshots
      # @since 0.1.5
      # @param file [String]
      # @param browser_output [Hash]
      # @return [Hash]
      def wraith_percentage(file, browser_output)
        file_object = File.open(file, 'rb')
        browser_output[:percent_changed] ||= {}
        browser_output[:percent_changed][File.basename(file).split('_')[0].to_i] = file_object.read.to_f

        file_object.close

        browser_output
      end

      # Make images temp files to save for later
      # Once this script exits, the images will delete themselves.
      #   We need those images, so the finalizer is left undefined.
      #   http://stackoverflow.com/a/21286718
      # @since 0.1.5
      # @param file [String]
      # @return [String] path to image
      def wraith_image(file)
        data = File.read(file)
        image = Tempfile.new([File.basename(file), '.png']).tap do |f|
          f.rewind
          f.write(data)
          ObjectSpace.undefine_finalizer(f)
          f.close
        end
        image.path
      end

  end
end
