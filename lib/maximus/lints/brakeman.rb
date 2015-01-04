module Maximus
  # @since 0.1.0
  class Brakeman < Maximus::Lint

    # Brakeman (requires Rails)
    # @see Lint#initialize
    def result

      @task = 'brakeman'
      @path = @settings[:root_dir] if @path.blank?

      return unless is_rails? && temp_config(@task) && path_exists(@path)

      tmp = Tempfile.new('brakeman')
      quietly { `brakeman #{@path} -f json -o #{tmp.path} -q` }
      brakeman = tmp.read
      tmp.close
      tmp.unlink

      unless brakeman.blank?
        bjson = JSON.parse(brakeman)
        @output[:ignored_warnings] = bjson['scan_info']['ignored_warnings']
        @output[:checks_performed] = bjson['scan_info']['checks_performed']
        @output[:number_of_controllers] = bjson['scan_info']['number_of_controllers']
        @output[:number_of_models] = bjson['scan_info']['number_of_models']
        @output[:number_of_templates] = bjson['scan_info']['number_of_templates']
        @output[:ruby_version] = bjson['scan_info']['ruby_version']
        @output[:rails_version] = bjson['scan_info']['rails_version']
        brakeman = {}
        ['warnings', 'errors'].each do |type|
          new_brakeman = bjson[type].group_by { |s| s['file'] }
          new_brakeman.each do |file, errors|
            if file
              brakeman[file.to_sym] = errors.map { |e| hash_for_brakeman(e, type) }
            end
          end
        end
        # The output of brakeman is a mix of strings and symbols
        #   but resetting the JSON like this standardizes everything.
        # @todo Better way to get around this?
        brakeman = JSON.parse(brakeman.to_json)
      end

      @output[:files_inspected] ||= files_inspected('rb', ' ')
      refine brakeman
    end


    private

      # Convert to {file:README.md Maximus format}
      # @param error [Hash] lint error
      # @return [Hash]
      def hash_for_brakeman(error, type)
        {
          linter: error['warning_type'],
          severity: type.chomp('s'),
          reason: error['message'],
          column: 0,
          line: error['line'].to_i,
          confidence: error['confidence']
        }
      end

  end
end
