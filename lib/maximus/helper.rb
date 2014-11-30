require 'rainbow'
require 'rainbow/ext/string'
require 'active_support'
require 'active_support/core_ext/object/blank'
require 'yaml'

module Maximus
  module Helper

    # See if Rails or a framework, i.e. Middleman
    # This will usually be stored as a class variable in the inherited class, like @@is_rails = is_rails? in lint.rb
    # Returns Boolean
    def is_rails?
      defined?(Rails)
    end

    # Get root directory of file being called
    # Returns String (path)
    def root_dir
      is_rails? ? Rails.root : Dir.pwd
    end

    # Verify that node module is installed on the box before continuing
    # Continues if module exists
    def node_module_exists(node_module)
      cmd = `if hash #{node_module} 2>/dev/null; then
        echo "true"
      else
        echo "false"
      fi`
      if cmd.include? "false"
        abort "#{'Missing node module'.color(:red)}: Please run `npm install -g #{node_module}` And try again\n"
      end
    end

    # Look for a custom config in the app's config/ directory; otherwise, use the built-in one
    # Returns String
    def check_default(filename)
      user_file = "#{root_dir}/config/#{filename}"
      File.exist?(user_file) ? user_file : File.join(File.dirname(__FILE__), "config/#{filename}")
    end

    # Grab the absolute path of the reporter file
    # Returns String
    def reporter_path(filename)
      File.join(File.dirname(__FILE__),"reporter/#{filename}")
    end

    # Find all files that were linted by extension
    # Returns Array
    def file_list(path, ext = 'scss', remover = '')
      collect_path = path.include?("*") ? path : "#{path}/**/*.#{ext}" #stupid, but necessary so that directories aren't counted
      Dir[collect_path].collect { |file| file.gsub(remover, '') if File.file?(file) }
    end

    # Count how many files were linted
    # Returns Integer
    def file_count(path, ext = 'scss')
      file_list(path, ext).length
    end

    # Convert string to boolean
    # Returns Boolean
    def truthy(str)
      return true if str == true || str =~ (/^(true|t|yes|y|1)$/i)
      return false if str == false || str.blank? || str =~ (/^(false|f|no|n|0)$/i)
    end

    # Edit and save a YAML file
    # Returns closed File
    def edit_yaml(yaml_location, &block)
      d = YAML.load_file(yaml_location)
      block.call(d)
      File.open(yaml_location, 'w') {|f| f.write d.to_yaml }
    end

    # Request user input
    # Returns user input as String
    def prompt(*args)
      print(*args)
      STDIN.gets
    end

    # Defines base log
    # Returns @@log variable for use
    def mlog
      @@log ||= Logger.new(STDOUT)
      @@log.level ||= Logger::INFO
      @@log
    end

    # Determine if current process was called by a rake task
    # Returns Boolean
    # http://stackoverflow.com/questions/2467208/how-can-i-tell-if-rails-code-is-being-run-via-rake-or-script-generate
    def is_rake_task?
      File.basename($0) == 'rake'
    end

  end
end
