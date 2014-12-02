module Maximus
  class Rubocop < Maximus::Lint

    # RuboCop
    def initialize(opts = {})
      super
      @task = 'rubocop'
      @path ||= @@is_rails ? "#{@opts[:root_dir]}/app" : "#{@opts[:root_dir]}/*.rb"

      rubo = `rubocop #{@path} --require #{reporter_path('rubocop')} --config #{check_default('rubocop.yml')} --format RuboCop::Formatter::MaximusRuboFormatter #{'-R' if @@is_rails}`

      @output[:files_inspected] ||= files_inspected('rb', ' ')
      refine rubo
    end

  end
end
