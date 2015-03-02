module Maximus
  # Evaluates quality of scss
  # @since 0.1.0
  class Scsslint < Maximus::Lint

    # SCSS-Lint
    # @see Lint#initialize
    def result
      @task = 'scsslint'
      @path = discover_path(@config.working_dir, 'stylesheets', 'scss')

      return unless temp_config(@task) && path_exists?(@path)

      scss = `scss-lint #{@path} -c #{temp_config(@task)} --format=JSON`
      @output[:files_inspected] ||= files_inspected('scss')
      refine scss
    end

  end
end
