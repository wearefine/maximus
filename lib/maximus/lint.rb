require 'rainbow'
require 'rainbow/ext/string'
require 'json'

module Maximus

  class Lint
    attr_accessor :output

    include Helper
    include Remote
    include VersionControl

    def initialize(output = {})
      git_data = VersionControl::GitControl.new(is_rails?)
      super
      @output = git_data.export
    end


    def check_empty(data)
      unless data.blank?
        @lint.refine(data, @task, @is_dev)
        puts @lint.format if @is_dev
      else
        @output[:lint_errors] = 0
        @output[:lint_warnings] = 0
        @output[:lint_conventions] = 0
        @output[:lint_refactors] = 0
      end
    end

    def refine(data, task, is_dev)
      error_list = JSON.parse(data)
      lint_warnings = []
      lint_errors = []
      lint_conventions = []
      lint_refactors = []
      error_list.each do |filename, error_list|
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

      @output[:lint_errors] = lint_errors.length
      @output[:lint_warnings] = lint_warnings.length
      @output[:lint_conventions] = lint_conventions.length
      @output[:lint_refactors] = lint_refactors.length
      @output[:refined_data] = lint_warnings.concat(lint_errors).concat(lint_conventions).concat(lint_refactors)
      @output[:raw_data] = error_list

      #If there's just too much to handle
      if @output[:refined_data].length > 100
        puts format(@output[:refined_data])
        failed_task = "#{task}".color(:green)
        errors = Rainbow("#{@output[:refined_data].length} failures.").red
        errormsg = "\n#{errors}\n"
        errormsg += ["You wouldn't stand a chance in Rome.\nResolve thy errors and train with #{failed_task} again.", "The gods frown upon you, mortal.\n#{failed_task}. Again.", "Do not embarrass the city. Fight another day. Use #{failed_task}.", "You are without honor. Replenish it with another #{failed_task}.", "You will never claim the throne with a performance like that.", "Pompeii has been lost."].sample
        errormsg += "\n\n"
        abort errormsg unless is_dev
      end

    end

    def format(errors = @output[:refined_data])

      pretty_output = ''
      errors.each do |error|
        pretty_output += error['filename'].color(:cyan)
        pretty_output += ":"
        pretty_output += error['line'].to_s.color(:magenta)
        pretty_output += " #{error['linter'].color(:green)}: "
        pretty_output += error['reason']
        pretty_output += "\n"
      end
      return pretty_output

    end

    def lint_post(name = '', is_dev = false)

      if @output[:lint_errors] > 0
        puts "#{'Warning'.color(:red)}: #{@output[:lint_errors]} errors found in #{name.to_s}"
        "#{name.to_s.color(:green)} complete"
      else
        success = name.to_s.color(:green)
        success += ": "
        success += "[#{@output[:lint_warnings]}]".color(:yellow)
        success += " " + "[#{@output[:lint_errors]}]".color(:red)
        success += " " + "[#{@output[:lint_conventions]}]".color(:cyan) if name == 'rubocop'
        success += " " + "[#{@output[:lint_refactors]}]".color(:white) if name == 'rubocop'
        puts success
      end

      remote(name, "lints/new/#{name}", @output) unless is_dev

    end
  end
end