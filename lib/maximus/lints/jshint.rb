module Maximus
  # @since 0.1.0
  class Jshint < Maximus::Lint

    # JSHint (requires node module)
    #
    # @see Lint#initialize
    def result
      @task = 'jshint'

      return unless check_default(@task)

      @path ||= is_rails? ? "#{@@settings[:root_dir]}/app/assets" : "#{@@settings[:root_dir]}source/assets"

      return unless path_exists(@path)

      node_module_exists(@task)

      jshint = `jshint #{@path} --config=#{check_default(@task)} --exclude-path=#{check_default(@@settings[:jshintignore])} --reporter=#{reporter_path('jshint.js')}`

      @output[:files_inspected] ||= files_inspected('js')
      refine jshint
    end

  end
end
