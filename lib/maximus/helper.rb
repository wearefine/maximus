require 'rainbow'
require 'rainbow/ext/string'
require 'active_support'
require 'active_support/core_ext/object/blank'
require 'yaml'

module Maximus
  # @since 0.1.0
  module Helper

    # See if project linted is a Rails app
    # This will usually be stored as a class variable in the inherited class
    # @example class variable
    #   @@is_rails = is_rails?
    #
    # @return [Boolean]
    def is_rails?
      defined?(Rails)
    end

    # Get root directory of file being called
    #
    # @return [String] absolute path to root directory
    def root_dir
      is_rails? ? Rails.root.to_s : Dir.pwd.to_s
    end

    # Verify that command is available on the box before continuing
    #
    # @param command [String] command to check
    # @param install_instructions [String] how to install the missing command
    # @return [void] aborts the action if command not found
    def node_module_exists(command, install_instructions = 'npm install -g')
      cmd = `if hash #{command} 2>/dev/null; then
        echo "true"
      else
        echo "false"
      fi`
      if cmd.include? "false"
        command_msg = "Missing command #{command}".color(:red)
        abort "#{command_msg}: Please run `#{install_instructions} #{command}` And try again\n"
        exit 1
      end
    end

    # Look for a config defined from Config#initialize
    #
    # @param filename [String]
    # @return [String] absolute path to the reporter file
    def check_default(search_for)
      @@settings[search_for.to_sym].blank? ? false : @config.temp_files[search_for.to_sym]
    end

    # Grab the absolute path of the reporter file
    #
    # @param filename [String]
    # @return [String] absolute path to the reporter file
    def reporter_path(filename)
      File.join(File.dirname(__FILE__), "reporter/#{filename}")
    end

    # Find all files that were linted by extension
    #
    # @param path [String] path to folders
    # @param ext [String] file extension to search for
    # @return [Array<String>] list of file paths
    def file_list(path, ext = 'scss', remover = '')
      # Necessary so that directories aren't counted
      collect_path = path.include?("*") ? path : "#{path}/**/*.#{ext}"
      # Remove first slash from path if present. probably a better way to do this.
      Dir[collect_path].collect { |file| file.gsub(remover, '').gsub(/^\/app\//, 'app/') if File.file?(file) }
    end

    # Count how many files were linted
    #
    # @param path [String] path to folders
    # @param ext [String] file extension to search for
    # @return [Integer] number of files matched by the path
    def file_count(path, ext = 'scss')
      file_list(path, ext).length
    end

    # Convert string to boolean
    #
    # @param str [String] the string to evaluate
    # @return [Boolean] whether or not the string is true
    def truthy(str)
      return true if str == true || str =~ (/^(true|t|yes|y|1)$/i)
      return false if str == false || str.blank? || str =~ (/^(false|f|no|n|0)$/i)
    end

    # Edit and save a YAML file
    #
    # @return [void]
    def edit_yaml(yaml_location, &block)
      d = YAML.load_file(yaml_location)
      block.call(d)
      File.open(yaml_location, 'w') {|f| f.write d.to_yaml }
    end

    # Request user input
    #
    # @param args [Array<String>] prompts to request
    # @return [String] user input to use elsewhere
    def prompt(*args)
      print(*args)
      STDIN.gets
    end

    # Defines base logger
    #
    # @param out [String, STDOUT] location for logging
    #   Accepts file path
    # @return [Logger] @@log for logging use
    def mlog(out)
      out ||= STDOUT
      @@log ||= Logger.new(out)
      @@log.level ||= Logger::INFO
      @@log
    end

    # Convert the array from lines_added into spelled-out ranges
    # This is a GitControl helper but it's used in Lint
    # @see GitControl#lines_added
    # @see Lint#relevant_lint
    #
    # @example typical output
    #   lines_added = {'filename' => ['0..10', '11..14']}
    #   lines_added_to_range(lines_added)
    #   # output
    #   {
    #     'filename': {
    #       {
    #         [0,1,2,3,4,5,6,7,8,9,10],
    #         [11,12,13,14]
    #       }
    #     }
    #   }
    #
    # @todo I'm sure there's a better way of doing this
    # @todo figure out a better place to put this than in Helper
    # @return [Hash] changes_array of spelled-out arrays of integers
    def lines_added_to_range(file)
      changes_array = file[:changes].map { |ch| ch.split("..").map(&:to_i) }
      changes_array.map { |e| (e[0]..e[1]).to_a }.flatten!
    end

    # Ensure path exists
    #
    # @param path [String, Array] path to files can be directory or glob
    # @return [Boolean]
    def path_exists(path = @path)
      path = path.split(' ') if path.is_a?(String) && path.include?(' ')
      if path.is_a?(Array)
        path.each do |p|
          unless File.exist?(p)
            puts "#{p} does not exist"
            return false
          end
        end
      else
        if File.exist?(path)
          return true
        else
          puts "#{path} does not exist"
          return false
        end
      end
    end

  end
end
