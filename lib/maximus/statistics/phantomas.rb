module Maximus
  # Evaluate page performance
  # @since 0.1.0
  class Phantomas < Maximus::Statistic

    # Run phantomas through the command line
    # @see Statistic#initialize
    def result

      return if @settings[:phantomas].blank?

      node_module_exists('phantomjs', 'brew install')
      node_module_exists('phantomas')

      @path = @settings[:paths] if @path.blank?
      @domain = @config.domain

      # Phantomas doesn't actually skip the skip-modules defined in the config BUT here's to hoping for future support
      phantomas_cli = "phantomas --config=#{@settings[:phantomas]} "
      phantomas_cli << @config.is_dev? ? '--colors' : '--reporter=json:no-skip'
      phantomas_cli << " --proxy=#{@domain}" if @domain.include?('localhost')
      @path.is_a?(Hash) ? @path.each { |label, url| phantomas_by_url(url, phantomas_cli) } : phantomas_by_url(@path, phantomas_cli)
      @output
    end


    private

      # Organize stat output on the @output variable
      # Adds @output[:statistics][:filepath] with all statistic data
      # @return [void] goes to refine statistics
      def phantomas_by_url(url, phantomas_cli)
        puts "Phantomas on #{@domain + url}".color(:green)
        phantomas = `#{phantomas_cli} #{@domain + url}`
        refine(phantomas, url)
      end

  end
end
