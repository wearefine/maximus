module Maximus
  # @since 0.1.0
  class Rubocop < Maximus::Lint

    # RuboCop
    # @see Lint#initialize
    def result
      @task = 'rubocop'
      @path = is_rails? ? "#{@config.pwd}/app" : "#{@config.pwd}/*.rb" if @path.blank?

      return unless temp_config(@task) && path_exists?(@path)

      rubo = `rubocop #{@path} --require #{reporter_path('rubocop')} --config #{temp_config(@task)} --format RuboCop::Formatter::MaximusRuboFormatter #{'-R' if is_rails?}`

      @output[:files_inspected] ||= files_inspected('rb', ' ')
      refine rubo
    end

  end
end
