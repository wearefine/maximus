
module Maximus
  class Statistic
    attr_accessor :output

    include Helper

    # Gather info about how the code performs
    #
    # All defined lints require a "result" method
    # @example the result method in the child class
    #   def result(opts = {})
    #     super
    #     @path ||= 'path/or/**/glob/to/files''
    #     stat_data = JSON.parse(`some-command-line-stat-runner`)
    #     @output
    #  end
    #
    # @param [Hash] opts the options to create a lint with.
    # @option opts [Boolean] :is_dev whether or not the class was initialized from the command line
    # @option opts [String] :root_dir base directory
    # @option opts [String] :base_url the host
    # @option opts [String, Integer] :post port number
    # @option opts [String, Array] :path ('') path to files. Accepts glob notation
    # @returns output [Hash] combined and refined data from statistic
    def initialize(opts = {})
      opts[:is_dev] ||= false
      opts[:root_dir] ||= root_dir
      opts[:port] ||= ''
      opts[:base_url] ||= 'http://localhost:3000'

      @@log ||= mlog
      @@is_rails ||= is_rails?
      @@is_dev = opts[:is_dev]
      @path = opts[:path]
      @opts = opts

      @output = {}
      # This is different from lints
      # A new stat is run per file or URL, so they should be stored in a child
      # A lint just has one execution, so it's data can be stored directly in @output
      @output[:statistics] = {}
    end


    protected

    # Organize stat output on the @output variable
    # Adds @output[:statistics][:filepath] with all statistic data
    def refine_stats(stats_cli, file_path)

      # Stop right there unless you mean business
      return puts stats_cli if @@is_dev

      # JSON.parse will throw an abortive error if it's given an empty string
      return false if stats_cli.blank?

      stats = JSON.parse(stats_cli)
      @output[:statistics][file_path.to_sym] ||= {}

      # TODO - is there a better way to do this?
      fp = @output[:statistics][file_path.to_s.to_sym]

      # TODO - Can I do like a self << thing here?
      stats.each do |stat, value|
        fp[stat.to_sym] = value
      end

      @output
    end

  end
end
