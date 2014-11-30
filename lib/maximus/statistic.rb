
module Maximus

  # Base Statistic class
  class Statistic
    attr_accessor :output

    include Helper

    # opts - Lint options (default: {})
    #    :is_dev - wether or not this is being called by a rake task
    #    :root_dir - absolute path to working directory (optional)
    #    :port - 4-digit port number (optional)
    #    :base_url - standard domain with http:// (default: http://localhost:3000) (optional)
    #    :path - default set in methods (optional)
    def initialize(opts = {}, output = {})
      opts[:is_dev] = true if opts[:is_dev].nil?
      opts[:root_dir] ||= root_dir
      opts[:port] ||= ''
      opts[:base_url] ||= 'http://localhost:3000'

      @@log ||= mlog
      @@is_rails ||= is_rails?
      @is_dev = opts[:is_dev]
      @output = output
      # This is different from lints
      # A new stat is run per file or URL, so they should be stored in a child
      # A lint just has one execution, so it's data can be stored directly in @output
      @output[:statistics] ||= {}
      @opts = opts
      @path = opts[:path]
    end


    protected

    # Organize stat output on the @output variable
    # Adds @output[:statistics][:filepath] with all statistic data
    def refine_stats(stats_cli, file_path)

      # Stop right there unless you mean business
      return puts stats_cli if @is_dev

      # JSON.parse will throw an abortive error if it's given an empty string
      return false if stats_cli.blank?

      stats = JSON.parse(stats_cli)
      @output[:statistics][file_path.to_sym] ||= {}

      # TODO - is there a better way to do this?
      fp = @output[:statistics][file_path.to_sym]

      # TODO - Can I do like a self << thing here?
      stats.each do |stat, value|
        fp[stat.to_sym] = value
      end

      @output
    end

  end
end
