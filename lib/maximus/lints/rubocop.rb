module Maximus
  class Rubocop < Maximus::Lint

    # RuboCop
    def result
      @task = 'rubocop'
      @path ||= @@is_rails ? "#{@opts[:root_dir]}/app" : "#{@opts[:root_dir]}/*.rb"

      return unless path_exists(@path)

      rubo = `rubocop #{@path} --require #{reporter_path('rubocop')} --config #{check_default('rubocop.yml')} --format RuboCop::Formatter::MaximusRuboFormatter #{'-R' if @@is_rails}`

      @output[:files_inspected] ||= files_inspected('rb', ' ')
      refine rubo
    end

  end
end
