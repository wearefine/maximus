require 'rake'

if defined?(Rails)
  module Maximus
    class Railtie < Rails::Railtie
      rake_tasks do
        Dir[File.join(File.dirname(__FILE__),'tasks/*.rake')].each { |f| load f }
      end
    end
  end
else
  Dir[File.join(File.dirname(__FILE__),'tasks/*.rake')].each { |f| load f }
end