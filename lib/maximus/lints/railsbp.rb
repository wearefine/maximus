module Maximus
  class Railsbp < Maximus::Lint

    # rails_best_practice (requires Rails)
    def initialize(opts = {})
      super

      return unless @@is_rails

      @task = 'railsbp'
      @path ||= @opts[:root_dir]
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
        railsbp = JSON.parse(railsbp.to_json) #don't event ask
      end

      @output[:files_inspected] ||= files_inspected('rb', ' ')
      refine railsbp
    end


    private

    # Convert to maximus format
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
