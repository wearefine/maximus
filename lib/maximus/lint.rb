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
      error_list.each do |all_errors|
        all_errors.each do |file_list|
          if file_list.is_a? String
            filename = file_list
          else
            file_list.each do |messaging|
              messaging['filename'] = filename
              if messaging['severity'] == 'warning'
                lint_warnings << messaging
              else
                lint_errors << messaging
              end
            end
          end
        end
      end
      @output[:lint_errors] = lint_errors.length
      @output[:lint_warnings] = lint_warnings.length
      @output[:refined_data] = lint_warnings.concat(lint_errors)
      @output[:raw_data] = error_list

      #If there's just too much to handle
      if @output[:refined_data].length > 100
        puts format(@output[:refined_data])
        failed_task = "rake #{t}".color(:green)
        errors = Rainbow("#{@output[:refined_data].length} failures.").red
        abort "\n#{errors}\nYou wouldn't stand a chance in Rome.\nResolve thy errors and train with #{failed_task} again.\n\n"
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

      if @output[:lint_errors] > 0
        "#{'Warning'.color(:red)}: #{@output[:lint_errors]} errors found in #{name}"
      else
        success = name.color(:green)
        success += ": "
        success += "[#{@output[:lint_warnings]}]".color(:yellow)
        success += " "
        success += "[#{@output[:lint_errors]}]".color(:red)
        success
      end
    end

  end
end