module Maximus
  # @since 0.1.0
  # @attr_accessor output [Hash] result of a lint parsed by Lint#refine
  class Statistic
    attr_accessor :output

    include Helper

    # Gather info about how the code performs
    #
    # All defined statistics require a "result" method
    # @example the result method in the child class
    #   def result
    #     @path ||= 'path/or/**/glob/to/files''
    #     stat_data = JSON.parse(`some-command-line-stat-runner`)
    #     @output
    #  end
    #
    # Inherits settings from {Config#initialize}
    # @param opts [Hash] ({}) options passed directly to statistic
    # @option file_paths [Array, String] stat only specific files or directories
    #   Accepts globs too
    #   which is used to define paths from the URL (see Statistics#initialize)
    # @option opts [Config object] :config custom Maximus::Config object
    # @return [void] this method is used to set up instance variables
    def initialize(opts = {})

      @@config ||= opts[:config] || Maximus::Config.new(opts)
      @settings ||= @@config.settings

      @path = opts[:file_paths] || @settings[:file_paths]

      @output = {}

      # This is different from lints
      #   A new stat is run per file or URL, so they should be stored in a child
      #   A lint just has one execution, so it's data can be stored directly in @output
      @output[:statistics] = {}
    end


    protected

    # Organize stat output on the @output variable
    #   Adds @output[:statistics][:filepath] with all statistic data
    #   Ignores if is_dev or if stats_cli is blank
    #
    # @param stats_cli [String] JSON data from a lint result
    # @param file_path [String] key value to organize stats output
    # @return [Hash] organized stats data
    def refine(stats_cli, file_path)

      # Stop right there unless you mean business
      return puts stats_cli if @@config.is_dev?

      # JSON.parse will throw an abortive error if it's given an empty string
      return false if stats_cli.blank?

      stats = JSON.parse(stats_cli)
      @output[:statistics][file_path.to_sym] ||= {}

      # @todo is there a better way to do this?
      fp = @output[:statistics][file_path.to_s.to_sym]

      # @todo Can I do like a self << thing here?
      stats.each do |stat, value|
        fp[stat.to_sym] = value
      end

      @output
    end

  end
end
