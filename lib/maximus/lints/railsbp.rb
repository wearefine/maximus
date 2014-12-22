module Maximus
  # @since 0.1.0
  class Railsbp < Maximus::Lint

    # rails_best_practice (requires Rails)
    #
    # @see Lint#initialize
    def result

      return unless is_rails?

      @task = 'railsbp'

      return unless temp_config(@task)

      @path = @settings[:root_dir] if @path.blank?

      return unless path_exists(@path)

      tmp = Tempfile.new('railsbp')
      `rails_best_practices #{@path} -f json --output-file #{tmp.path}`
      railsbp = tmp.read
      tmp.close
      tmp.unlink

      unless railsbp.blank?
        rbj = JSON.parse(railsbp).group_by { |s| s['filename'] }
        railsbp = {}
        rbj.each do |file, errors|
          if file
            # This crazy gsub grapbs scrubs the absolute path from the filename
            railsbp[file.gsub(Rails.root.to_s, '')[1..-1].to_sym] = errors.map { |o| hash_for_railsbp(o) }
          end
        end
        # The output of railsbp is a mix of strings and symbols
        #   but resetting the JSON like this standardizes everything.
        # @todo Better way to get around this?
        railsbp = JSON.parse(railsbp.to_json)
      end

      @output[:files_inspected] ||= files_inspected('rb', ' ')
      refine railsbp
    end


    private

    # Convert to {file:README.md Maximus format}
    #
    # @param error [Hash] lint error
    # @return [Hash]
    def hash_for_railsbp(error)
      {
        linter: error['message'].gsub(/\((.*)\)/, '').strip.parameterize('_').camelize,
        severity: 'warning',
        reason: error['message'],
        column: 0,
        line: error['line_number'].to_i
      }
    end

  end
end
