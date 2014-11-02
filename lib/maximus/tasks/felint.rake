require 'net/http'
require 'git'
require 'rainbow'
require 'rainbow/ext/string'

desc "Run some sweet lint scripts and post them to the main hub"

def lint_globals
  @project = Rails.root.to_s.split('/').last
  @g = Git.open(Rails.root, :log => Logger.new("#{Rails.root}/log/maximus_git.log"))
  @sha = @g.object('HEAD').sha
  branch = `env -i git rev-parse --abbrev-ref HEAD`
  master_commit = @g.branches[:master].gcommit
  commit = @g.gcommit(@sha)
  diff = @g.diff(commit, master_commit).stats
  @output = {
    project: {
      name: @project,
      remote_repo: (@g.remotes.first.url if @g.remotes.present?)
    },
    git: {
      commitsha: @sha,
      branch: branch,
      message: commit.message,
      deletions: diff[:total][:deletions],
      insertions: diff[:total][:insertions],
      raw_data: diff
    },
    user: {
      name: @g.config('user.name'),
      email: @g.config('user.email')
    },
  }
end

def check_node_module(node_module)
  cmd = `if hash #{node_module} 2>/dev/null; then
    echo "true"
  else
    echo "false"
  fi`
  if cmd.include? "false"
    abort("#{'Missing node module'.color(:red)}: Please run `npm install -g #{node_module}` And try again\n")
  end
end

def felint_refine(data, t)
  error_list = JSON.parse(data)
  lint_warnings = []
  lint_errors = []
  filename = ''
  error_list.each do |all_errors|
    all_errors.each do |file_list|
      if file_list.is_a? String
        filename = file_list
      else
        file_list.each do |messaging|
          messaging['filename'] = filename
          if messaging['severity'] == 'warning'
            lint_warnings << messaging
          else
            lint_errors << messaging
          end
        end
      end
    end
  end
  @output[:lint_errors] = lint_errors.length
  @output[:lint_warnings] = lint_warnings.length
  @output[:refined_data] = lint_warnings.concat(lint_errors)
  @output[:raw_data] = error_list

  if @output[:refined_data].length > 150
    puts format_output(@output[:refined_data])
    failed_task = "rake #{t}".color(:green)
    abort("\n#{'Failure.'.color(:red)} You wouldn't stand a chance in Rome.\nResolve thy errors and train with #{failed_task} again.\n\n")
  end
end

def lint_post(name)
  uri = URI("http://localhost:3001/lint/new/#{name}")
  req = Net::HTTP::Post.new(uri, initheader = {'Content-Type' =>'application/json'})
  req.basic_auth 'user54', 'pass77'
  req.body = @output.to_json
  res = Net::HTTP.start(uri.hostname, uri.port) do |http|
    http.request(req)
  end
  if @output[:lint_errors] > 0
    puts "#{'Warning'.color(:red)}: #{@output[:lint_errors]} errors found in #{name}"
  else
    success = name.color(:green)
    success += ": "
    success += "[#{@output[:lint_warnings]}]".color(:yellow)
    success += " "
    success += "[#{@output[:lint_errors]}]".color(:red)
    puts success
  end
end

def check_default(filename)
  user_file = "#{Rails.root}/config/#{filename}"
  return File.exist?(user_file) ? user_file : File.expand_path("../../config/#{filename}", __FILE__)
end

def get_file_count(path)
  @output[:file_count] = Dir[path].count { |file| File.file?(file) }
end

def format_output(errors)

  pretty_output = ''
  errors.each do |error|
    pretty_output += error['filename'].color(:cyan)
    pretty_output += ":"
    pretty_output += error['line'].to_s.color(:magenta)
    pretty_output += " #{error['linter'].color(:green)}: "
    pretty_output += error['reason']
    pretty_output += "\n"
  end
  return pretty_output

end


namespace :maximus do
  namespace :fe do

    desc "Run scss-lint" #scss-lint Rake API was challenging
    task :scss, :dev, :path do |t, args|
      `scss-lint -v`
      args.with_defaults(:dev => false, :path => "app/assets/stylesheets/")
      is_dev = args[:dev] == 'true' ? true : false
      config_file = check_default('scss-lint.yml')
      scss_cli = "scss-lint #{args[:path]} -c #{config_file}  --format=JSON"

      lint_globals
      scss = `#{scss_cli}`
      felint_refine(scss, t)
      format_output(@output[:refined_data])

      @output[:division] = 'front'
      count_path = args[:path].include?("*") ? args[:path] : "#{args[:path]}/**/*.scss" #stupid, but necessary so that directories aren't counted
      get_file_count(count_path)

      lint_post('scss_lint') unless is_dev

    end

    desc "Run jshint (node required)"
    task :js, :dev, :path do |t, args|
      args.with_defaults(:dev => false, :path => 'app/assets/**/*.js')
      is_dev = args[:dev] == 'true' ? true : false

      check_node_module('jshint')

      config_file = check_default('jshint.json')
      exclude_file = check_default('.jshintignore')
      jshint_cli = "jshint #{args[:path]} --config=#{config_file} --exclude-path=#{exclude_file} --reporter=#{File.expand_path("../../config/jshint-reporter.js", __FILE__)}"

      jshint = `#{jshint_cli}`

      unless jshint.empty?

          lint_globals
          felint_refine(jshint, t)
          format_output(@output[:refined_data])

      else

        puts "No JSHint errors"

        @output[:lint_errors] = 0
        @output[:lint_warnings] = 0

      end

      @output[:division] = 'front'
      get_file_count(args[:path])
      lint_post('jshint') unless is_dev

    end

    task :stylestats, :dev do |t, args|
      check_node_module('stylestats')
      if Gem::Specification::find_all_by_name('compass').any?
        Compass.sass_engine_options[:load_paths].each do |path|
          Sass.load_paths << path
        end
      end
      Dir.glob('app/assets/**/*').select {|f| File.directory? f}.each do |file|
        Sass.load_paths << file
      end
      scss_file = File.open("app/assets/stylesheets/website/application.css.scss", 'rb') { |f| f.read }

      puts Sass::Engine.new(scss_file, { syntax: :scss, quiet: true, style: :compressed }).render
    end

    desc "Get everything done at once"
    task :all => [:scss, :js]

  end
  desc "Argument less task"
  task :fe => 'fe:all'
end
