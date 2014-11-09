require 'rainbow'
require 'rainbow/ext/string'
require 'active_support'
require 'active_support/core_ext/object/blank'
require 'json'

module Maximus

  class Statistic
    attr_accessor :output

    include Helper
    include Remote
    include VersionControl

    def initialize(output = {})

      super
      @output = VersionControl::GitControl.new(is_rails?).export

      @output[:statistics] = {}
      @output[:statistics][:files] = {} #Is this necessary

    end

  end
end