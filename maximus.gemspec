# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'maximus/version'

Gem::Specification.new do |spec|
  spec.name          = "maximus"
  spec.version       = Maximus::VERSION
  spec.authors       = ["Tim Shedor"]
  spec.email         = ["tim@wearefine.com"]
  spec.summary       = %q{Run tests and save them to the Colosseum}
  spec.description   = %q{Supports scss-lint, jshint, rubocop, brakeman and rails_best_practices. Statistics include phantomas, stylestats and wraith}
  spec.homepage      = ""
  spec.license       = "MIT"

  spec.files         = `git ls-files -z`.split("\x0")
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.add_runtime_dependency "git", ">= 1.2.8"
  spec.add_runtime_dependency "scss-lint", ">= 0.29.0"
  spec.add_runtime_dependency "rainbow"
  spec.add_runtime_dependency "rubocop"
  spec.add_runtime_dependency "rails_best_practices"
  spec.add_runtime_dependency "brakeman"
  spec.add_runtime_dependency "wraith"
  spec.add_runtime_dependency "activesupport"
  spec.add_runtime_dependency "thor"
  spec.add_runtime_dependency "rake"
  spec.add_development_dependency "bundler", "~> 1.6"
end
