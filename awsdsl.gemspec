# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'awsdsl/version'

Gem::Specification.new do |spec|
  spec.name          = 'awsdsl'
  spec.version       = AWSDSL::VERSION
  spec.authors       = ['Joseph Glanville']
  spec.email         = ['jpg@jpg.id.au']
  spec.summary       = 'A simple DSL for deploying and running apps on AWS'
  spec.description   = 'A simple DSL for deploying and running apps on AWS'
  spec.homepage      = 'https://github.com/josephglanville/awsdsl'
  spec.license       = 'MIT'

  spec.files         = `git ls-files -z`.split("\x0")
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ['lib']

  spec.add_runtime_dependency 'aws-sdk', '~> 1.61'
  spec.add_runtime_dependency 'activesupport', '~> 4'
  spec.add_runtime_dependency 'cfndsl'

  spec.add_development_dependency 'bundler', '~> 1.7'
  spec.add_development_dependency 'rake', '~> 10.0'
  spec.add_development_dependency 'pry', '~> 0.10'
  spec.add_development_dependency 'rspec', '~> 3.2'
end