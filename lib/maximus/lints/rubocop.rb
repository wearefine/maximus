module Maximus
  # @since 0.1.0
  class Rubocop < Maximus::Lint

    # RuboCop
    #
    # @see Lint#initialize
    def result
      @task = 'rubocop'

      return unless temp_config(@task)

      @path = is_rails? ? "#{@settings[:root_dir]}/app" : "#{@settings[:root_dir]}/*.rb" if @path.blank?

      return unless path_exists(@path)

      rubo = `rubocop #{@path} --require #{reporter_path('rubocop')} --config #{temp_config(@task)} --format RuboCop::Formatter::MaximusRuboFormatter #{'-R' if is_rails?}`

      @output[:files_inspected] ||= files_inspected('rb', ' ')
      refine rubo
    end

  end
end
