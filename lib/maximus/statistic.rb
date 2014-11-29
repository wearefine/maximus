
module Maximus

  # Base Statistic class
  class Statistic
    attr_accessor :output

    include Helper

    def initialize(is_dev = true, output = {})
      @@is_dev = is_dev
      @@output = output
      @@is_rails = is_rails?
    end

  end
end
