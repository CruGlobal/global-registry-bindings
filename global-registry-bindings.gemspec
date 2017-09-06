# coding: utf-8
# frozen_string_literal: true

lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'global_registry_bindings/version'

Gem::Specification.new do |s|
  s.name = 'global-registry-bindings'
  s.version = ::GlobalRegistry::Bindings::VERSION
  s.authors = ['Brian Zoetewey']
  s.email = ['brian.zoetewey@cru.org']
  s.summary = 'ActiveRecord bindings for Global Registry'
  s.description = 'Provides a common interface for mapping ActiveRecord ' \
                  'models to Global Registry entities and relationships.'
  s.homepage = 'https://github.com/CruGlobal/global-registry-bindings'
  s.license = 'MIT'
  s.files = Dir.glob('lib/**/*') + %w[MIT-LICENSE README.md]
  s.test_files = Dir.glob('spec/**/*')
  s.require_paths = ['lib']

  s.required_ruby_version = '>= 2.3.0'

  s.add_runtime_dependency 'activerecord', '>= 4.0.0', '< 6'
  s.add_runtime_dependency 'global_registry', '~> 1.4', '< 2'
  s.add_runtime_dependency 'sidekiq', '>= 4.0.0', '< 6'
  s.add_runtime_dependency 'sidekiq-unique-jobs', '>= 5.0.0', '< 6'

  s.add_development_dependency 'appraisal'
  s.add_development_dependency 'combustion', '~> 0.6.0'
  s.add_development_dependency 'rails', '>= 4.2.2'
  s.add_development_dependency 'bundler', '~>1.14'
  s.add_development_dependency 'rake', '~> 12'
  s.add_development_dependency 'rspec-rails', '~> 3.5.0'
  s.add_development_dependency 'webmock', '~> 3.0.0'
  s.add_development_dependency 'factory_girl', '~> 4.8.0'
  s.add_development_dependency 'rubocop', '0.48.1'
  s.add_development_dependency 'database_cleaner'
  s.add_development_dependency 'sqlite3'
  s.add_development_dependency 'mock_redis', '~> 0.17.0'
  s.add_development_dependency 'simplecov', '~> 0.14.0'
  s.add_development_dependency 'pry'
  s.add_development_dependency 'pry-byebug'
end
