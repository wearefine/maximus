module Maximus
  class Scsslint < Maximus::Lint

    # SCSS-Lint
    def result
      @task = 'scsslint'
      @path ||= @@is_rails ? "#{@opts[:root_dir]}/app/assets/stylesheets" : "#{@opts[:root_dir]}/source/assets/stylesheets"
      scss = `scss-lint #{@path} -c #{check_default('scsslint.yml')}  --format=JSON`

      @output[:files_inspected] ||= files_inspected('scss')
      refine scss
    end

  end
end
