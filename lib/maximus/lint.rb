require 'git'
require 'rainbow'
require 'rainbow/ext/string'
require 'active_support'
require 'active_support/core_ext/object/blank'
require 'json'

module Maximus

  class Lint
    attr_accessor :output
    def initialize(output = {})
      root_dir = @is_rails ? Rails.root : Dir.pwd
      log = @is_rails ? Logger.new("#{root_dir}/log/maximus_git.log") : nil
      project = root_dir.to_s.split('/').last
      @g = Git.open(root_dir, :log => log)
      sha = @g.object('HEAD').sha
      branch = `env -i git rev-parse --abbrev-ref HEAD`
      master_commit = @g.branches[:master].gcommit
      commit = @g.gcommit(sha)
      diff = @g.diff(commit, master_commit).stats
      @output = {
        project: {
          name: project,
          remote_repo: (@g.remotes.first.url unless @g.remotes.blank?)
        },
        git: {
          commitsha: sha,
          branch: branch,
          message: commit.message,
          deletions: diff[:total][:deletions],
          insertions: diff[:total][:insertions],
          raw_data: diff
        },
        user: {
          name: @g.config('user.name'),
          email: @g.config('user.email')
        },
      }
    end

    def refine(data, t)
      error_list = JSON.parse(data)
      lint_warnings = []
      lint_errors = []
      filename = ''
      error_list.each do |filename, error_list|
        error_list.each do |message|
          message['filename'] = filename
          if message['severity'] == 'warning'
            lint_warnings << message
          else
            lint_errors << message
          end
        end
      end
      @output[:errors] = lint_errors.length
      @output[:warnings] = lint_warnings.length
      @output[:refined_data] = lint_warnings.concat(lint_errors)
      @output[:raw_data] = error_list

      #If there's just too much to handle
      if @output[:refined_data].length > 100
        puts format(@output[:refined_data])
        failed_task = "rake #{t}".color(:green)
        errors = Rainbow("#{@output[:refined_data].length} failures.").red
        errormsg = "\n#{errors}\n"
        errormsg += ["You wouldn't stand a chance in Rome.\nResolve thy errors and train with #{failed_task} again.", "The gods frown upon you, mortal.\n#{failed_task}. Again.", "Do not embarrass your city. Fight another day. #{failed_task}", "You are without honor. Replenish it with #{failed_task}.", "You will never claim the throne with a #{failed_task} performance like that.", "Pompeii has been lost."].sample
        errormsg += "\n\n"
        abort errormsg
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

    def after_post(name)

      if @output[:errors] > 0
        "#{'Warning'.color(:red)}: #{@output[:errors]} errors found in #{name}"
      else
        success = name.color(:green)
        success += ": "
        success += "[#{@output[:warnings]}]".color(:yellow)
        success += " "
        success += "[#{@output[:errors]}]".color(:red)
        success
      end
    end

  end
end