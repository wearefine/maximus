require 'json'

module Maximus
  class Lint

    attr_accessor :output

    include Helper

    # opts - Lint options (default: {})
    #    :is_dev
    #    :from_git
    #    :path
    def initialize(opts = {}, output = {})

      opts[:is_dev] = true if opts[:is_dev].nil?
      opts[:from_git] = false if opts[:from_git].nil?

      @@log ||= mlog
      @@is_rails ||= is_rails?
      @@is_dev = opts[:is_dev]
      @output = output
      @@is_rails = is_rails?

      @opts = opts
      @path = opts[:path]

    end

    # Convert raw data into warnings, errors, conventions or refactors. Use this wisely.
    # Returns complete @output as Hash
    def refine(data, task = @task)
      lint_warnings = []
      lint_errors = []
      lint_conventions = []
      lint_refactors = []
      unless data.blank?
        data.each do |filename, error_list|
          error_list.each do |message|
            message = message.clone # so that :raw_data remains unaffected
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
      lint_all = []
      lint_all.concat(lint_warnings).concat(lint_errors).concat(lint_conventions).concat(lint_refactors)

      lint_summarize task
      if @@is_dev
        lint_dev_format(data) unless data.blank?
        lint_ceiling(lint_all.length, task)
      end
      @output[:raw_data] = data.to_json # Because this should be returned in the format it was received
      @output
    end


    protected

    # Give git a little more data to help it out
    # If it's from git explicitly, we're looking at line numbers.
    # There's a call in version_control.rb for all lints, and that is not considered 'from_git' because it's not filtering the results and instead taking them all indiscriminately
    def hash_for_git(data)
      if data.is_a? String
        data = JSON.parse(data) unless data.blank?
      end
      {
        data: data,
        lint: @lint,
        task: @task
      }
    end

    # List all files inspected
    # Returns Array
    def files_inspected(ext, delimiter = ',', replace = '')
      @output[:files_inspected] = @path.is_a?(Array) ? @path.split(delimiter) : file_list(@path, ext, replace)
    end

    # Convert export depending on execution origin
    def hash_or_refine(data, parse_JSON = true)
      if parse_JSON
        data = data.blank? ? data : JSON.parse(data) # defend against blank JSON errors
      end
      @opts[:from_git] ? hash_for_git(data) : refine(data, @task)
    end


    private

    # Send abbreviated results to console or to the log
    # Returns console message
    def lint_summarize(task = @task)
      puts "\n" if @@is_dev

      puts "#{'Warning'.color(:red)}: #{@output[:lint_errors].length} errors found in #{task.to_s}" if @output[:lint_errors].length > 0

      success = task.to_s.color(:green)
      success += ": "
      success += "[#{@output[:lint_warnings].length}]".color(:yellow)
      success += " " + "[#{@output[:lint_errors].length}]".color(:red)
      success += " " + "[#{@output[:lint_conventions].length}]".color(:cyan) if task == 'rubocop'
      success += " " + "[#{@output[:lint_refactors].length}]".color(:white) if task == 'rubocop'

      if @@is_dev
        puts success
      else
        @@log.info success
      end
    end

    # If there's just too much to handle, through a warning. MySQL may not store everything and throw an abortive error if the blob is too large
    # Returns prompt if lint_length is greater than 100
    # If prompt returns truthy, execution continues
    def lint_ceiling(lint_length, task = @task)
      if lint_length > 100
        lint_dev_format
        failed_task = "#{task}".color(:green)
        errors = Rainbow("#{lint_length} failures.").red
        errormsg = ["You wouldn't stand a chance in Rome.\nResolve thy errors and train with #{failed_task} again.", "The gods frown upon you, mortal.\n#{failed_task}. Again.", "Do not embarrass the city. Fight another day. Use #{failed_task}.", "You are without honor. Replenish it with another #{failed_task}.", "You will never claim the throne with a performance like that.", "Pompeii has been lost.", "A wise choice. Do not be discouraged from another #{failed_task}."].sample
        errormsg += "\n\n"

        go_on = prompt "\n#{errors} Continue? (y/n) "
        abort errormsg unless truthy(go_on)
      end
    end

    # Dev display, used for the rake task
    # Returns console message
    def lint_dev_format(errors = @output[:raw_data])
      pretty_output = ''
      errors.each do |filename, error_list|
        pretty_output += "\n"
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
      puts pretty_output
    end

  end
end
