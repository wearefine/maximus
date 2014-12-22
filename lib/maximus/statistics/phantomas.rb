module Maximus
  # @since 0.1.0
  class Phantomas < Maximus::Statistic

    # Phantomas evaluates page performance with phantomjs and node
    #
    # @see Statistic#initialize
    def result

      node_module_exists('phantomjs', 'brew install')
      node_module_exists('phantomas')

      @path ||= @@settings[:paths]
      # Phantomas doesn't actually skip the skip-modules defined in the config BUT here's to hoping for future support
      phantomas_cli = "phantomas --config=#{check_default('phantomas')} "
      phantomas_cli += @@is_dev ? '--colors' : '--reporter=json:no-skip'
      phantomas_cli += " --proxy=#{@@settings[:domain]}:#{@@settings[:port]}" unless @@settings[:port].blank? || @@settings[:domain].include?(':')
      @path.is_a?(Hash) ? @path.each { |label, url| phantomas_by_url(url, phantomas_cli) } : phantomas_by_url(@path, phantomas_cli)
      @output
    end


    private

    # Organize stat output on the @output variable
    # Adds @output[:statistics][:filepath] with all statistic data
    # @return [void] goes to refine statistics
    def phantomas_by_url(url, phantomas_cli)
      puts "Phantomas on #{@@settings[:domain] + url}".color(:green)
      phantomas = `#{phantomas_cli} #{@@settings[:domain] + url}`
      refine_stats(phantomas, url)
    end

  end
end
