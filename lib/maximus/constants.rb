# Global application constants.
module HamlLint
  IS_RAILS = defined?(Rails)
  MAXIMUS_ROOT = IS_RAILS ? Rails.root : Dir.pwd
  MAXIMUS_REMOTE_URL = 'http://localhost:3001/'
end
