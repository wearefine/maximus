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

    def refine(data, task = @task, is_dev = @is_dev)
      is_dev ||= false # in case @is_dev is unavailable

      lint_warnings = []
      lint_errors = []
      lint_conventions = []
      lint_refactors = []
      unless data.blank?
        data.each do |filename, error_list|
          error_list.each do |message|
            message['filename'] = filename
            if message['severity'] == 'warning'
              lint_warnings << message
            elsif message['severity'] == 'error'
              lint_errors << message
            elsif message['severity'] == 'convention'
              lint_conventions << message
            elsif message['severity'] == 'refactor'
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

      lint_all = lint_warnings.concat(lint_errors).concat(lint_conventions).concat(lint_refactors)

      if is_dev
        puts format(lint_all) unless lint_all.blank?
      else
        lint_ceiling(lint_all, task)
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
        @output.merge(GitControl.new.export)
        Remote.new(task, "lints/new/#{task}", @output)
      end
    end

    private

    #If there's just too much to handle
    def lint_ceiling(lint_all, task)
      if lint_all.length > 100
        puts format(lint_all)
        failed_task = "#{task}".color(:green)
        errors = Rainbow("#{lint_all.length} failures.").red
        errormsg = ["You wouldn't stand a chance in Rome.\nResolve thy errors and train with #{failed_task} again.", "The gods frown upon you, mortal.\n#{failed_task}. Again.", "Do not embarrass the city. Fight another day. Use #{failed_task}.", "You are without honor. Replenish it with another #{failed_task}.", "You will never claim the throne with a performance like that.", "Pompeii has been lost.", "A wise choice. Do not be discouraged from another #{failed_task}."].sample
        errormsg += "\n\n"

        go_on = prompt "\n#{errors} Continue? (y/n) "
        abort errormsg unless truthy(go_on)
      end
    end

    def format(errors)
      pretty_output = ''
      errors.each do |error|
        pretty_output += case error['severity']
          when 'warning' then 'W'.color(:yellow)
          when 'error' then 'E'.color(:red)
          when 'convention' then 'C'.color(:cyan)
          when 'refactor' then 'R'.color(:white)
        end
        pretty_output += ' '
        pretty_output += error['filename'].color(:cyan)
        pretty_output += ':'
        pretty_output += error['line'].to_s.color(:magenta)
        pretty_output += " #{error['linter'].color(:green)}: "
        pretty_output += error['reason']
        pretty_output += "\n"
      end
      return pretty_output
    end

  end
end