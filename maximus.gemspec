# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'maximus/version'

Gem::Specification.new do |spec|
  spec.name          = "maximus"
  spec.version       = Maximus::VERSION
  spec.authors       = ["Tim Shedor"]
  spec.email         = ["tshedor@gmail.com"]
  spec.summary       = %q{Make your code spic and <span>}
  spec.description   = %q{The all-in-one linting solution}
  spec.homepage      = "https://github.com/wearefine/maximus"
  spec.license       = "MIT"

  spec.files         = `git ls-files -z`.split("\x0")
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.add_runtime_dependency "git", "~> 1.2.9"
  spec.add_runtime_dependency "scss-lint", "~> 0.33.0"
  spec.add_runtime_dependency "rainbow", "2.0.0"
  spec.add_runtime_dependency "rubocop", "~> 0.29"
  spec.add_runtime_dependency "rails_best_practices", "~> 1.15"
  spec.add_runtime_dependency "brakeman", "~> 3.0.1"
  spec.add_runtime_dependency "wraith", "~> 2.3"
  spec.add_runtime_dependency "activesupport"
  spec.add_runtime_dependency "thor"

  spec.add_development_dependency "bundler", "~> 1.6"
  spec.add_development_dependency "pry-byebug", "~> 3.0"
  spec.add_development_dependency "yard", "~> 0.8"
  spec.add_development_dependency "rspec", "~> 3.0"
  spec.add_development_dependency "coveralls", "~> 0.7.8"
end
