module Maximus
  class Lint

    # SCSS-Lint
    def scsslint
      @task = __method__.to_s
      @path ||= @@is_rails ? "app/assets/stylesheets" : "source/assets/stylesheets"

      scss = `scss-lint #{@path} -c #{check_default('scsslint.yml')}  --format=JSON`

      @output[:files_inspected] ||= files_inspected('scss')
      refine scss
    end

  end
end