require 'net/http'
require 'git'
require 'rainbow'
require 'rainbow/ext/string'
require 'json'
require 'active_support'
require 'active_support/core_ext/object/blank'

desc "Run some sweet lint scripts and post them to the main hub"

def is_rails
  defined?(Rails)
end

def lint_globals
  root_dir = is_rails ? Rails.root : Dir.pwd
  log = is_rails ? Logger.new("#{root_dir}/log/maximus_git.log") : nil
  @project = root_dir.to_s.split('/').last
  @g = Git.open(root_dir, :log => log)
  @sha = @g.object('HEAD').sha
  branch = `env -i git rev-parse --abbrev-ref HEAD`
  master_commit = @g.branches[:master].gcommit
  commit = @g.gcommit(@sha)
  diff = @g.diff(commit, master_commit).stats
  @output = {
    project: {
      name: @project,
      remote_repo: (@g.remotes.first.url unless @g.remotes.blank?)
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

  #If there's just too much to handle
  if @output[:refined_data].length > 100
    puts format_output(@output[:refined_data])
    failed_task = "rake #{t}".color(:green)
    errors = Rainbow("#{@output[:refined_data].length} failures.").red
    abort "\n#{errors}\nYou wouldn't stand a chance in Rome.\nResolve thy errors and train with #{failed_task} again.\n\n"
  end

end

def fe_post(name, url)
  uri = URI(url)
  req = Net::HTTP::Post.new(uri, initheader = {'Content-Type' =>'application/json'})
  req.basic_auth 'user54', 'pass77'
  req.body = @output.to_json
  res = Net::HTTP.start(uri.hostname, uri.port) do |http|
    http.request(req)
  end
end

def lint_post(name)
  fe_post(name, "http://localhost:3001/lint/new/#{name}")
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
  root_dir = is_rails ? Rails.root : Dir.pwd
  user_file = "#{root_dir}/config/#{filename}"
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
    task :scss, [:dev, :path] do |t, args|

      args.with_defaults(:dev => false, :path => (is_rails ? "app/assets/stylesheets/" : "source/assets/stylesheets") )
      is_dev = args[:dev] == 'true' ? true : false

      lint_globals

      config_file = check_default('scss-lint.yml')

      scss = `scss-lint #{args[:path]} -c #{config_file}  --format=JSON`
      felint_refine(scss, t)
      puts format_output(@output[:refined_data]) if is_dev

      @output[:division] = 'front'
      count_path = args[:path].include?("*") ? args[:path] : "#{args[:path]}/**/*.scss" #stupid, but necessary so that directories aren't counted
      get_file_count(count_path)

      lint_post('scss_lint') unless is_dev

    end

    desc "Run jshint (node required)"
    task :js, :dev, :path do |t, args|

      check_node_module('jshint')

      args.with_defaults(:dev => false, :path => (is_rails ? "app/assets/**" : "source/assets/**") )
      is_dev = args[:dev] == 'true' ? true : false

      config_file = check_default('jshint.json')
      exclude_file = check_default('.jshintignore')
      jshint = `jshint #{args[:path]} --config=#{config_file} --exclude-path=#{exclude_file} --reporter=#{File.expand_path("../../config/jshint-reporter.js", __FILE__)}`

      unless jshint.empty?

          lint_globals
          felint_refine(jshint, t)
          puts format_output(@output[:refined_data]) if is_dev

      else

        @output[:lint_errors] = 0
        @output[:lint_warnings] = 0

      end

      @output[:division] = 'front'
      get_file_count(args[:path])
      lint_post('jshint') unless is_dev

    end

    task :stylestats, :dev, :path do |t, args|

      check_node_module('stylestats')

      args.with_defaults(:dev => false, :path => (is_rails ? 'app/assets/**/*' : 'source/assets/**/*') )
      is_dev = args[:dev] == 'true' ? true : false

      lint_globals

      #Load Compass paths if it exists
      if Gem::Specification::find_all_by_name('compass').any?
        require 'compass' unless is_rails
        Compass.sass_engine_options[:load_paths].each do |path|
          Sass.load_paths << path
        end
      end

      #Toggle default looks for rails or middleman
      search_for_scss = args[:path]

      Dir.glob(search_for_scss).select {|f| File.directory? f}.each do |file|
        Sass.load_paths << file
      end

      search_for_scss += ".css.scss"

      #Prep for stylestats
      config_file = check_default('.stylestatsrc')

      @output[:statistics] = {}
      @output[:statistics][:files] = {} #what am i doing wrong
      Dir[search_for_scss].select { |file| File.file? file }.each do |file|

        scss_file = File.open(file, 'rb') { |f| f.read }

        output_file = File.open( file.split('.').reverse.drop(1).reverse.join('.'), "w" )
        output_file << Sass::Engine.new(scss_file, { syntax: :scss, quiet: true, style: :compressed }).render
        output_file.close


        stylestats = "stylestats #{output_file.path} --config=#{config_file} --type=json"
        puts "Stylestatting #{file.color(:green)}"
        if is_dev

          puts `#{stylestats.gsub('--type=json', '')}`

        else
          stats = JSON.parse(`#{stylestats}`)
          symbol_file = output_file.path.to_sym
          @output[:statistics][:files][symbol_file] = {} #still doing something wrong here
          file_collection = @output[:statistics][:files][symbol_file]

          stats.each do |stat, value|

            file_collection[stat.to_sym] = value

          end

          @output[:raw_data] = stats

          File.delete(output_file)

        end

      end

      @output[:division] = 'front'

      fe_post('stylestats', 'http://localhost:3001/statistic/new/stylestats') unless is_dev

    end

    desc "Get everything done at once"
    task :all => [:scss, :js, :stylestats]

  end
  desc "Argument less task"
  task :fe => 'fe:all'
end
