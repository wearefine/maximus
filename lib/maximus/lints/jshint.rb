module Maximus
  # Evaluates quality of JavaScript
  # @since 0.1.0
  class Jshint < Maximus::Lint

    # JSHint (requires node module)
    # @see Lint#initialize
    def result
      @task = 'jshint'
      @path = is_rails? ? "#{@config.working_dir}/app/assets" : "#{@config.working_dir}source/assets" if @path.blank?

      return unless temp_config(@task) && path_exists?(@path)

      node_module_exists(@task)

      jshint_cli = "jshint #{@path} --config=#{temp_config(@task)} --reporter=#{reporter_path('jshint.js')}"
      jshint_cli += " --exclude-path=#{temp_config(@settings[:jshintignore])}" if @settings.has_key?(:jshintignore)
      jshint = `#{jshint_cli}`

      @output[:files_inspected] ||= files_inspected('js')
      refine jshint
    end

  end
end
