module Maximus
  class Lint

    # JSHint (requires node module)
    def jshint
      @task = __method__.to_s
      @path ||= @@is_rails ? "app/assets" : "source/assets"

      node_module_exists(@task)

      jshint = `jshint #{@path} --config=#{check_default('jshint.json')} --exclude-path=#{check_default('.jshintignore')} --reporter=#{reporter_path('jshint.js')}`

      files_inspected('js')
      hash_or_refine(jshint)
    end

  end
end
