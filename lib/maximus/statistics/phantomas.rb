module Maximus

  class Statistic

    # @path can be array or string of URLS. Include http://
    # By default, checks homepage
    def phantomas
      node_module_exists('phantomas')

      @path ||= YAML.load_file(check_default('phantomas_urls.yaml'))
      # Phantomas doesn't actually skip the skip-modules defined in the config BUT here's to hoping for future support
      phantomas_cli = "phantomas --config=#{check_default('phantomas.json')} "
      phantomas_cli += @is_dev ? '--colors' : '--reporter=json:no-skip'
      phantomas_cli += " --proxy=#{@opts[:base_url]}:#{@opts[:port]}" unless @opts[:port].blank?
      @path.is_a?(Hash) ? @path.each { |label, url| phantomas_by_url(url, phantomas_cli) } : phantomas_by_url(@path, phantomas_cli)
      @output
    end


    private

    # Organize stat output on the @output variable
    # Adds @output[:statistics][:filepath] with all statistic data
    def phantomas_by_url(url, phantomas_cli)
      puts "Phantomas on #{@opts[:base_url] + url}".color(:green)
      phantomas = `#{phantomas_cli} #{@opts[:base_url] + url}`
      refine_stats(phantomas, url)
    end

  end
end