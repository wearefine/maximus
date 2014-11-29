require 'maximus/constants'
require 'maximus/version'
require 'maximus/helper'
require 'maximus/git_control'
require 'maximus/lint'
require 'maximus/lint_task'
require 'maximus/statistic'
require 'maximus/statistic_task'
require 'maximus/rake_tasks'

# Rainbow color highlighting key
# Blue    - System/unrelated
# Red     - Error/Danger/Line Number
# Yellow  - Warning
# Cyan    - Filename/Convention
# White   - Refactor
# Green   - Success/Lint Name/Linter Name