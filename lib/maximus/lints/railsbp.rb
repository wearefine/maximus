module Maximus
  # Evaluates quality of Rails methods
  # @since 0.1.0
  class Railsbp < Maximus::Lint

    # rails_best_practice (requires Rails)
    # @see Lint#initialize
    def result

      @task = 'railsbp'
      @path = @config.working_dir if @path.blank?

      return unless is_rails? && temp_config(@task) && path_exists?(@path)

      tmp = Tempfile.new('railsbp')
      `rails_best_practices #{@path} -f json --output-file #{tmp.path}`
      railsbp = tmp.read
      tmp.close
      tmp.unlink

      unless railsbp.blank?
        rbj = JSON.parse(railsbp).group_by { |s| s['filename'] }
        railsbp = {}
        rbj.each do |file, errors|
          next unless file

          # This crazy gsub scrubs the absolute path from the filename
          filename = file.gsub(Rails.root.to_s, '')[1..-1]
          railsbp[filename] = errors.map { |o| hash_for_railsbp(o) }

        end
      end

      @output[:files_inspected] ||= files_inspected('rb', ' ')
      refine railsbp
    end


    private

      # Convert to {file:README.md Maximus format}
      # @param error [Hash] lint error
      # @return [Hash]
      def hash_for_railsbp(error)
        {
          'linter' => error['message'].gsub(/\((.*)\)/, '').strip.parameterize('_').camelize,
          'severity' => 'warning',
          'reason' => error['message'],
          'column' => 0,
          'line' => error['line_number'].to_i
        }
      end

  end
end
