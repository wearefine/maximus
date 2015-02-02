require 'maximus'
require 'coveralls'
Coveralls.wear!

RSpec.configure do |config|
  config.mock_with :rspec do |c|
    c.syntax = [:should, :expect]
  end
end
