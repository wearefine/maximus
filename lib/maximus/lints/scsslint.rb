module Maximus
  # @since 0.1.0
  class Scsslint < Maximus::Lint

    # SCSS-Lint
    #
    # @see Lint#initialize
    def result
      @task = 'scsslint'

      return unless check_default(@task)

      @path ||= @@is_rails ? "#{@@settings[:root_dir]}/app/assets/stylesheets" : "#{@@settings[:root_dir]}/source/assets/stylesheets"

      return unless path_exists(@path)

      scss = `scss-lint #{@path} -c #{check_default(@task)}`
      @output[:files_inspected] ||= files_inspected('scss')
      refine scss
    end

  end
end
