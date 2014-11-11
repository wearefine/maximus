require 'active_support'
require 'active_support/core_ext/object/blank'

module Maximus
  module Helper

    def initialize(is_rails = nil)
      @is_rails = is_rails?
    end

    def is_rails?
      defined?(Rails)
    end

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

    def check_default(filename)
      root_dir = @is_rails ? Rails.root : Dir.pwd
      user_file = "#{root_dir}/config/#{filename}"
      File.exist?(user_file) ? user_file : File.expand_path("../config/#{filename}", __FILE__)
    end

    def file_count(path, ext = 'scss')
      count_path = path.include?("*") ? path : "#{path}/**/*.#{ext}" #stupid, but necessary so that directories aren't counted
      Dir[count_path].count { |file| File.file?(file) }
    end

    def truthy(str)
      return true if str == true || str =~ (/^(true|t|yes|y|1)$/i)
      return false if str == false || str.blank? || str =~ (/^(false|f|no|n|0)$/i)
    end

    def prompt(*args)
      print(*args)
      STDIN.gets
    end
  end
end