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
      is_rails? ? Rails.root.to_s : Dir.pwd.to_s
    end

    # Verify that node module is installed on the box before continuing
    # Continues if module exists
    def node_module_exists(node_module, install_instructions = 'npm install -g')
      cmd = `if hash #{node_module} 2>/dev/null; then
        echo "true"
      else
        echo "false"
      fi`
      if cmd.include? "false"
        command_msg = "Missing command #{node_module}".color(:red)
        abort "#{command_msg}: Please run `#{install_instructions} #{node_module}` And try again\n"
      end
    end

    # Look for a custom config in the app's config/ directory; otherwise, use the built-in one
    # TODO - best practice that this inherits the @@opts from the model it's being included in?
    # Returns String
    def check_default(filename)
      user_file = "#{@opts[:root_dir]}/config/#{filename}"
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
      # Necessary so that directories aren't counted
      collect_path = path.include?("*") ? path : "#{path}/**/*.#{ext}"
      # Remove first slash from path if present. probably a better way to do this.
      Dir[collect_path].collect { |file| file.gsub(remover, '').gsub(/^\/app\//, 'app/') if File.file?(file) }
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

    # Convert the array from lines_added into spelled-out ranges
    # Example: lines_added = {'filename' => ['0..10', '11..14']}
    # Becomes {'filename' => {[0,1,2,3,4,5,6,7,8,9,10], [11,12,13,14]}}
    # This is a git_control helper primarily but it's used in Lint
    # TODO - I'm sure there's a better way of doing this
    # TODO - figure out a better place to put this than in Helper
    # Returns Hash of spelled-out arrays of integers
    def lines_added_to_range(file)
      changes_array = file[:changes].map { |ch| ch.split("..").map(&:to_i) }
      changes_array.map { |e| (e[0]..e[1]).to_a }.flatten!
    end

  end
end
