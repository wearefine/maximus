require 'json'
require 'rainbow'

module Maximus

  # Parent class for all lints (inherited by children)
  # @since 0.1.0
  # @attr_accessor output [Hash] result of a lint parsed by Lint#refine
  class Lint
    attr_accessor :output

    include Helper

    # Perform a lint of relevant code
    #
    # All defined lints require a "result" method
    # @example the result method in the child class
    #   def result
    #     @task = __method__.to_s
    #     @path ||= 'path/or/**/glob/to/files''
    #     lint_data = JSON.parse(`some-command-line-linter`)
    #     @output[:files_inspected] ||= files_inspected(extension, delimiter, base_path_replacement)
    #     refine data_from_output
    #   end
    #
    # Inherits settings from {Config#initialize}
    # @see Config#initialize
    #
    # @param opts [Hash] ({}) options passed directly to the lint
    # @option opts [Hash] :git_files filename: file location
    #   @see GitControl#lints_and_stats
    # @option opts [Array, String] :file_paths lint only specific files or directories
    #   Accepts globs too
    #   which is used to define paths from the URL
    # @option opts [Config object] :config custom Maximus::Config object
    # @return [void] this method is used to set up instance variables
    def initialize(opts = {})

      # Only run the config once
      @config = opts[:config] || Maximus::Config.new(opts)
      @settings = @config.settings

      @git_files = opts[:git_files]
      @path = opts[:file_paths] || @settings[:file_paths]
      @output = {}
    end

    # Convert raw data into warnings, errors, conventions or refactors. Use this wisely.
    # @param data [Hash] unfiltered lint data
    # @return [Hash] refined lint data and all the other bells and whistles
    def refine(data)
      @task ||= ''

      data = parse_data(data)
      return puts data if data.is_a?(String)

      evaluate_severities(data)

      puts summarize

      if @config.is_dev?
        puts dev_format(data)
        ceiling_warning
      else
        # Because this should be returned in the format it was received
        @output[:raw_data] = data.to_json
      end
      @output
    end


    protected

      # List all files inspected
      # @param ext [String] extension to search for
      # @param delimiter [String] comma or space separated
      # @param remove [String] remove from all file names
      # @return all_files [Array<string>] list of file names
      def files_inspected(ext, delimiter = ',', remove = @config.working_dir)
        @path.is_a?(Array) ? @path.split(delimiter) : file_list(@path, ext, remove)
      end

      # Compare lint output with lines changed in commit
      # @param lint [Hash] output lint data
      # @param files [Hash<String: String>] filename: filepath
      # @return [Array] lints that match the lines in commit
      def relevant_output(lint, files)
        all_files = {}
        files.each do |file|

          # sometimes data will be blank but this is good - it means no errors were raised in the lint
          next if lint.blank? || file.blank? || !file.is_a?(Hash) || !file.key?(:filename)
          lint_file = lint[file[:filename]]

          next if lint_file.blank?

          expanded = lines_added_to_range(file)
          revert_name = strip_working_dir(file[:filename])

          all_files[revert_name] = []

          lint_file.each do |l|
            if expanded.include?(l['line'].to_i)
              all_files[revert_name] << l
            end
          end

          # If there's nothing there, then it definitely isn't a relevant lint
          all_files.delete(revert_name) if all_files[revert_name].blank?
        end
        @output[:files_linted] = all_files.keys
        all_files
      end

      # Look for a config defined from Config#initialize
      # @since 0.1.2
      # @param search_for [String]
      # @return [String, Boolean] path to temp file
      def temp_config(search_for)
        return false if @settings.nil?
        @settings[search_for.to_sym].blank? ? false : @settings[search_for.to_sym]
      end

      # Add severities to @output
      # @since 0.1.5
      # @param data [Hash]
      def evaluate_severities(data)
        @output[:lint_warnings] = []
        @output[:lint_errors] = []
        @output[:lint_conventions] = []
        @output[:lint_refactors] = []
        @output[:lint_fatals] = []

        return if data.blank?

        data.each do |filename, error_list|
          error_list.each do |message|
            # so that :raw_data remains unaffected
            message = message.clone
            message.delete('length')
            message['filename'] = filename.nil? ? '' : strip_working_dir(filename)
            severity = "lint_#{message['severity']}s".to_sym
            message.delete('severity')
            @output[severity] << message if @output.key?(severity)
          end
        end
        @output
      end

      # Convert the array from lines_added into spelled-out ranges
      # This is a GitControl helper but it's used in Lint
      # @see GitControl#lines_added
      # @see Lint#relevant_lint
      #
      # @example typical output
      #   lines_added = {changes: ['0..10', '11..14']}
      #   lines_added_to_range(lines_added)
      #   # output
      #   [0,1,2,3,4,5,6,7,8,9,10, 11,12,13,14]
      #
      # @return [Hash] changes_array of spelled-out arrays of integers
      def lines_added_to_range(file)
        changes_array = file[:changes].map { |ch| ch.split("..").map(&:to_i) }
        changes_array.map { |e| (e[0]..e[1]).to_a }.flatten!
      end


    private

      # Send abbreviated results to console or to the log
      # @return [String] console message to display
      def summarize
        success = @task.color(:green)
        success << ": "
        success << "[#{@output[:lint_warnings].length}]".color(:yellow)
        success << " [#{@output[:lint_errors].length}]".color(:red)
        if @task == 'rubocop'
          success << " [#{@output[:lint_conventions].length}]".color(:cyan)
          success << " [#{@output[:lint_refactors].length}]".color(:white)
          success << " [#{@output[:lint_fatals].length}]".color(:magenta)
        end
        success << "\n#{'Warning'.color(:red)}: #{@output[:lint_errors].length} errors found in #{@task}" if @output[:lint_errors].length > 0

        success
      end

      # If there's just too much to handle, through a warning.
      # @param lint_length [Integer] count of how many lints
      # @return [String] console message to display
      def ceiling_warning
        lint_length = (@output[:lint_errors].length + @output[:lint_warnings].length + @output[:lint_conventions].length + @output[:lint_refactors].length + @output[:lint_fatals].length)
        return unless lint_length > 100

        failed_task = @task.color(:green)
        errors = "#{lint_length} failures.".color(:red)
        errormsg = [
          "You wouldn't stand a chance in Rome.\nResolve thy errors and train with #{failed_task} again.",
          "The gods frown upon you, mortal.\n#{failed_task}. Again.",
          "Do not embarrass the city. Fight another day. Use #{failed_task}.",
          "You are without honor. Replenish it with another #{failed_task}.",
          "You will never claim the throne with a performance like that.",
          "Pompeii has been lost.",
          "A wise choice. Do not be discouraged from another #{failed_task}."
        ].sample
        errormsg << "\n\n"

        go_on = prompt "\n#{errors} Continue? (y/n) "
        abort errormsg unless truthy?(go_on)
      end

      # Dev display, executed only when called from command line
      # @param errors [Hash] data from lint
      # @return [String] console message to display
      def dev_format(errors = @output[:raw_data])
        return if errors.blank?

        pretty_output = ''
        errors.each do |filename, error_list|
          filename = strip_working_dir(filename)
          pretty_output << "\n#{filename.color(:cyan).underline} \n"
          error_list.each do |message|
            pretty_output << severity_color(message['severity'])
            pretty_output << " #{message['line'].to_s.color(:blue)} #{message['linter'].color(:green)}: #{message['reason']} \n"
          end
        end
        pretty_output << "-----\n\n"
        pretty_output
      end

      # String working directory
      # @since 0.1.6
      # @param path [String]
      # @return [String]
      def strip_working_dir(path)
        path.gsub(@config.working_dir, '')
      end

      # Handle data and generate relevant_output if appropriate
      # @since 0.1.6
      # @see #refine
      # @param data [String, Hash]
      # @return [String, Hash] String if error, Hash if success
      def parse_data(data)
        # Prevent abortive empty JSON.parse error
        data = '{}' if data.blank?

        return "Error from #{@task}: #{data}" if data.is_a?(String) && data.include?('No such')

        data = JSON.parse(data) if data.is_a?(String)

        @output[:relevant_output] = relevant_output( data, @git_files ) unless @git_files.blank?
        data = @output[:relevant_output] unless @settings[:commit].blank?
        data
      end

      def severity_color(severity)
        case severity
          when 'warning' then 'W'.color(:yellow)
          when 'error' then 'E'.color(:red)
          when 'convention' then 'C'.color(:cyan)
          when 'refactor' then 'R'.color(:white)
          when 'fatal' then 'F'.color(:magenta)
          else '?'.color(:blue)
        end
      end

  end
end
