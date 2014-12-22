require 'json'

module Maximus
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
    #  end
    #
    # Inherits settings from {Config#initialize}
    #
    # @param opts [Hash] ({}) options passed directly to the lint
    # @option git_files [Hash] filename: file location
    #   @see GitControl#lints_and_stats
    # @option file_paths [Array, String] lint only specific files or directories
    #   Accepts globs too
    #   which is used to define paths from the URL
    # @option opts [Config object] :config custom Maximus::Config object
    # @return [void] this method is used to set up instance variables
    def initialize(opts = {})

      # Only run the config once
      @@config ||= opts[:config] || Maximus::Config.new(opts)
      @settings ||= @@config.settings

      @git_files = opts[:git_files]
      @path = opts[:file_paths] || @settings[:file_paths]
      @output = {}
    end

    # Convert raw data into warnings, errors, conventions or refactors. Use this wisely.
    #
    # @param data [Hash] unfiltered lint data
    # @return [Hash] refined lint data and all the other bells and whistles
    def refine(data)
      # Prevent abortive empty JSON.parse error
      data = '{}' if data.blank?
      return puts "Error from #{@task}: #{data}" if data.is_a?(String) && data.include?('No such')

      data = data.is_a?(String) ? JSON.parse(data) : data

      @output[:relevant_lints] = relevant_lints( data, @git_files ) unless @git_files.blank?
      unless @settings[:commit].blank?
        data = @output[:relevant_lints]
      end

      lint_warnings = []
      lint_errors = []
      lint_conventions = []
      lint_refactors = []
      unless data.blank?
        data.each do |filename, error_list|
          error_list.each do |message|
            # so that :raw_data remains unaffected
            message = message.clone
            message.delete('length')
            message['filename'] = filename
            if message['severity'] == 'warning'
              message.delete('severity')
              lint_warnings << message
            elsif message['severity'] == 'error'
              message.delete('severity')
              lint_errors << message
            elsif message['severity'] == 'convention'
              message.delete('severity')
              lint_conventions << message
            elsif message['severity'] == 'refactor'
              message.delete('severity')
              lint_refactors << message
            end
          end
        end
      end
      @output[:lint_errors] = lint_errors
      @output[:lint_warnings] = lint_warnings
      @output[:lint_conventions] = lint_conventions
      @output[:lint_refactors] = lint_refactors
      lint_count = (lint_errors.length + lint_warnings.length + lint_conventions.length + lint_refactors.length)
      if @@config.is_dev?
        puts lint_dev_format(data) unless data.blank?
        puts lint_summarize
        lint_ceiling lint_count
      else
        @@config.log.info lint_summarize
        # Because this should be returned in the format it was received
        @output[:raw_data] = data.to_json
      end
      @@config.destroy_temp(@task)
      @output
    end


    protected

    # List all files inspected
    #
    # @param ext [String] extension to search for
    # @param delimiter [String] comma or space separated
    # @param remove [String] remove from all file names
    # @return all_files [Array<string>] list of file names
    def files_inspected(ext, delimiter = ',', remove = @settings[:root_dir])
      @path.is_a?(Array) ? @path.split(delimiter) : file_list(@path, ext, remove)
    end

    # Compare lint output with lines changed in commit
    #
    # @param lint [Hash] output lint data
    # @param files [Hash<String: String>] filename: filepath
    # @return [Array] lints that match the lines in commit
    def relevant_lints(lint, files)
      all_files = {}
      files.each do |file|

        # sometimes data will be blank but this is good - it means no errors raised in the lint
        unless lint.blank?
          lint_file = lint[file[:filename].to_s]

          expanded = lines_added_to_range(file)
          revert_name = file[:filename].gsub("#{@settings[:root_dir]}/", '')
          unless lint_file.blank?
            all_files[revert_name] = []

            # @todo originally I tried .map and delete_if, but this works,
            #   and the other method didn't cover all bases.
            #   Gotta be a better way to write this though
            lint_file.each do |l|
              if expanded.include?(l['line'].to_i)
                all_files[revert_name] << l
              end
            end
            # If there's nothing there, then it definitely isn't a relevant lint
            all_files.delete(revert_name) if all_files[revert_name].blank?
          end
        else
          # Optionally store the filename with a blank array
          #   @example all_files[file[:filename].to_s.gsub("#{@settings[:root_dir]}/", '')] = []
        end
      end
      @output[:files_linted] = all_files.keys
      all_files
    end

    # Look for a config defined from Config#initialize
    #
    # @since 0.1.2
    # @param search_for [String]
    # @return [String, Boolean] path to temp file
    def temp_config(search_for)
      return false if @settings.nil?
      @settings[search_for.to_sym].blank? ? false : @settings[search_for.to_sym]
    end


    private

    # Send abbreviated results to console or to the log
    #
    # @return [String] console message to display
    def lint_summarize
      puts "\n" if @@config.is_dev?

      puts "#{'Warning'.color(:red)}: #{@output[:lint_errors].length} errors found in #{@task.to_s}" if @output[:lint_errors].length > 0

      success = @task.to_s.color(:green)
      success += ": "
      success += "[#{@output[:lint_warnings].length}]".color(:yellow)
      success += " " + "[#{@output[:lint_errors].length}]".color(:red)
      if @task == 'rubocop'
        success += " " + "[#{@output[:lint_conventions].length}]".color(:cyan)
        success += " " + "[#{@output[:lint_refactors].length}]".color(:white)
      end

      success
    end

    # If there's just too much to handle, through a warning.
    # MySQL may not store all the data and throw an abortive error if the blob is too large
    # If prompt returns truthy, execution continues
    #
    # @param lint_length [Integer] count of how many lints
    # @return [String] console message to display
    def lint_ceiling(lint_length)
      if lint_length > 100
        lint_dev_format
        failed_task = "#{@task}".color(:green)
        errors = Rainbow("#{lint_length} failures.").red
        errormsg = ["You wouldn't stand a chance in Rome.\nResolve thy errors and train with #{failed_task} again.", "The gods frown upon you, mortal.\n#{failed_task}. Again.", "Do not embarrass the city. Fight another day. Use #{failed_task}.", "You are without honor. Replenish it with another #{failed_task}.", "You will never claim the throne with a performance like that.", "Pompeii has been lost.", "A wise choice. Do not be discouraged from another #{failed_task}."].sample
        errormsg += "\n\n"

        go_on = prompt "\n#{errors} Continue? (y/n) "
        abort errormsg unless truthy(go_on)
      end
    end

    # Dev display, executed only when called from command line
    #
    # @param errors [Hash] data from lint
    # @return [String] console message to display
    def lint_dev_format(errors = @output[:raw_data])
      return if errors.blank?
      pretty_output = ''
      errors.each do |filename, error_list|
        pretty_output += "\n"
        filename = filename.gsub("#{@settings[:root_dir]}/", '')
        pretty_output += filename.color(:cyan).underline
        pretty_output += "\n"
        error_list.each do |message|
          pretty_output += case message['severity']
            when 'warning' then 'W'.color(:yellow)
            when 'error' then 'E'.color(:red)
            when 'convention' then 'C'.color(:cyan)
            when 'refactor' then 'R'.color(:white)
            else '?'.color(:blue)
          end
          pretty_output += ' '
          pretty_output += message['line'].to_s.color(:blue)
          pretty_output += " #{message['linter'].color(:green)}: "
          pretty_output += message['reason']
          pretty_output += "\n"
        end
      end
      pretty_output
    end

  end
end
