require 'maximus'
require 'coveralls'
Coveralls.wear!

RSpec.configure do |config|
  config.before { allow($stdout).to receive(:puts) }
  config.mock_with :rspec do |c|
    c.syntax = [:should, :expect]
  end
end
