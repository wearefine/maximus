module Maximus
  class Lint

    # RuboCop
    def rubocop
      @task = __method__.to_s
      @path ||= @@is_rails ? "app" : "*.rb"

      rubo_cli = "rubocop #{@path} --require #{reporter_path('rubocop')} --config #{check_default('rubocop.yml')} --format RuboCop::Formatter::MaximusRuboFormatter"
      rubo_cli += " -R" if @@is_rails
      rubo = `#{rubo_cli}`

      @output[:files_inspected] ||= files_inspected('rb', ' ')
      refine rubo
    end

  end
end