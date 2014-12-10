require 'maximus/constants'
require 'maximus/version'
require 'maximus/helper'
require 'maximus/git_control'
require 'maximus/lint'
require 'maximus/statistic'

# Get statistics
Dir[File.expand_path('maximus/statistics/*.rb', File.dirname(__FILE__))].each do |file|
  require file
end

# Get lints
Dir[File.expand_path('maximus/lints/*.rb', File.dirname(__FILE__))].each do |file|
  require file
end

# Rainbow color highlighting key
# Blue    - System/unrelated
# Red     - Error/Danger/Line Number
# Yellow  - Warning
# Cyan    - Filename/Convention
# White   - Refactor
# Green   - Success/Lint Name/Linter Name
