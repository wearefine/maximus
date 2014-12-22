module Maximus
  # @since 0.1.0
  class Scsslint < Maximus::Lint

    # SCSS-Lint
    #
    # @see Lint#initialize
    def result
      @task = 'scsslint'

      return unless temp_config(@task)
      @path = is_rails? ? "#{@settings[:root_dir]}/app/assets/stylesheets" : "#{@settings[:root_dir]}/source/assets/stylesheets" if @path.blank?

      return unless path_exists(@path)

      scss = `scss-lint #{@path} -c #{temp_config(@task)} --format=JSON`
      @output[:files_inspected] ||= files_inspected('scss')
      refine scss
    end

  end
end
