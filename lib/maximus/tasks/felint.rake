require 'net/http'
require 'git'

desc "Run some sweet lint scripts and post them to the main hub"

def lint_globals
  @project = Rails.root.to_s.split('/').last
  @g = Git.open(Rails.root)
  @sha = @g.object('HEAD').sha
  branch = `env -i git rev-parse --abbrev-ref HEAD`
  master_commit = @g.branches[:master].gcommit
  commit = @g.gcommit(@sha)
  diff = @g.diff(commit, master_commit).stats
  @output = {
    project: {
      name: @project,
      remote_repo: @g.remotes.first.url
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

def felint_refine(data)
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
end

def lint_post(name)
  uri = URI("http://localhost:3001/lint/new/#{name}")
  req = Net::HTTP::Post.new(uri, initheader = {'Content-Type' =>'application/json'})
  req.basic_auth 'user54', 'pass77'
  req.body = @output.to_json
  res = Net::HTTP.start(uri.hostname, uri.port) do |http|
    http.request(req)
  end
end

def check_default(filename)
  user_file = "#{Rails.root}/config/#{filename}"
  return File.exist?(user_file) ? user_file : "#{Dir.pwd}/config/#{filename}"
end

namespace :felint do

  desc "Run scss-lint" #scss-lint Rake API was challenging
  task :scss, :dev, :path do |t, args|

    args.with_defaults(:dev => false, :path => 'app/assets/stylesheets/website/')
    is_dev = args[:dev] == 'true' ? true : false

    config_file = check_default('scss-lint.yml')

    scss_cli = "scss-lint #{args[:path]} -c #{config_file}"

    if is_dev

      puts %x[#{scss_cli}]

    else

      scss_cli += " --format=JSON"
      lint_globals
      scss=`#{scss_cli}`
      felint_refine(scss)
      @output[:division] = 'front'
      lint_post('scss_lint')

    end
  end

  desc "Run jshint (node required)"
  task :jshint, :dev, :path do |t, args|
    args.with_defaults(:dev => false, :path => 'app/assets/javascripts/**/*.js')
    is_dev = args[:dev] == 'true' ? true : false

    has_node_dep=`node #{Dir.pwd}/config/check_node_dependencies.js`
    unless has_node_dep
      abort('Please install the node dependencies')
    end

    config_file = check_default('jshint.json')
    exclude_file = check_default('.jshintignore')

    jshint_cli = "jshint -c #{config_file} #{args[:path]} --exclude-path=#{exclude_file}"

    if is_dev

      puts %x[#{jshint_cli}]

    else

      jshint_cli += " --reporter=#{Dir.pwd}/config/jshint-reporter.js"
      lint_globals
      jshint=`#{jshint_cli}`
      felint_refine(jshint)
      @output[:division] = 'front'
      lint_post('jshint')

    end
  end

  desc "Get everything done at once"
  task :all => [:scss, :jshint]

end

desc "Argument less task"
task :felint => 'felint:all'