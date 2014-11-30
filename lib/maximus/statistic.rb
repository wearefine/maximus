
module Maximus

  # Base Statistic class
  class Statistic
    attr_accessor :output

    include Helper

    def initialize(is_dev = true, output = {})
      @@log = mlog
      @@is_dev = is_dev
      @@output = output
      @@output[:statistics] = {}
      @@is_rails = is_rails?
    end

    # Organize stat output on the @@output variable
    # Adds @@output[:statistics][:filepath] with all statistic data
    def refine_stats(stats_cli, file_path)

      return puts stats_cli if @@is_dev # Stop right there unless you mean business

      return false if stats_cli.blank? # JSON.parse will throw an abortive error if it's given an empty string

      stats = JSON.parse(stats_cli)
      @@output[:statistics][file_path.to_sym] ||= {}
      fp = @@output[:statistics][file_path.to_sym] # TODO - is there a better way to do this?
      stats.each do |stat, value|
        fp[stat.to_sym] = value # TODO - Can I do like a self << thing here?
      end

      @@output
    end

  end
end
