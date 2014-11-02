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
  spec.description   = %q{Currently supports scss-lint, jshint, and stylestats}
  spec.homepage      = ""
  spec.license       = "MIT"

  spec.files         = `git ls-files -z`.split("\x0")
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.add_development_dependency "git", ">= 1.2.8"
  spec.add_development_dependency "scss-lint", ">= 0.29.0"
  spec.add_development_dependency "rainbow"
  spec.add_development_dependency "activesupport"
  spec.add_development_dependency "bundler", "~> 1.6"
  spec.add_development_dependency "rake"
end
