require 'rainbow'
require 'rainbow/ext/string'
require 'json'

module Maximus

  class Lint
    attr_accessor :output

    include Helper

    def initialize(output = {})
      @output ||= {}
    end

    # Convert raw data into warnings, errors, conventions or refactors. Use this wisely.
    def refine(data, task = @task, is_dev = @is_dev)
      is_dev ||= false # in case @is_dev is unavailable
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
      @output[:raw_data] = data
      lint_all = []
      lint_all.concat(lint_warnings).concat(lint_errors).concat(lint_conventions).concat(lint_refactors)

      if is_dev
        format(data) unless data.blank?
      else
        lint_ceiling(lint_all.length, task)
      end
      lint_post(task, is_dev)

    end

    # POST lint to main hub
    def lint_post(task = '', is_dev = false)

      puts "#{'Warning'.color(:red)}: #{@output[:lint_errors].length} errors found in #{task.to_s}" if @output[:lint_errors].length > 0

      success = task.to_s.color(:green)
      success += ": "
      success += "[#{@output[:lint_warnings].length}]".color(:yellow)
      success += " " + "[#{@output[:lint_errors].length}]".color(:red)
      success += " " + "[#{@output[:lint_conventions].length}]".color(:cyan) if task == 'rubocop'
      success += " " + "[#{@output[:lint_refactors].length}]".color(:white) if task == 'rubocop'

      puts success

      unless is_dev

        @output.merge!(GitControl.new.export)
        Remote.new("mercury/new/l/#{task}", @output)

      end
    end

    private

    # If there's just too much to handle
    def lint_ceiling(lint_length, task)
      if lint_length > 100
        format
        failed_task = "#{task}".color(:green)
        errors = Rainbow("#{lint_length} failures.").red
        errormsg = ["You wouldn't stand a chance in Rome.\nResolve thy errors and train with #{failed_task} again.", "The gods frown upon you, mortal.\n#{failed_task}. Again.", "Do not embarrass the city. Fight another day. Use #{failed_task}.", "You are without honor. Replenish it with another #{failed_task}.", "You will never claim the throne with a performance like that.", "Pompeii has been lost.", "A wise choice. Do not be discouraged from another #{failed_task}."].sample
        errormsg += "\n\n"

        go_on = prompt "\n#{errors} Continue? (y/n) "
        abort errormsg unless truthy(go_on)
      end
    end

    # Dev display, used in the rake task
    def format(errors = @output[:raw_data])
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