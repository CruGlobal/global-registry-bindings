# frozen_string_literal: true

require 'rubygems'
require 'bundler/setup'
require 'pry'

require 'active_record'
require 'active_job'
ActiveRecord::Migration.verbose = false

require 'combustion'
Combustion.initialize! :active_record

Combustion::Database.setup

require 'rspec/rails'
require 'rspec/rails/matchers/active_job'
require 'webmock/rspec'
require 'factory_girl'
require 'simplecov'

require 'global_registry_bindings'
require 'global_registry_bindings/testing'

ActiveJob::Base.queue_adapter = :test
ActiveJob::Base.logger = nil

ActionController::Base.cache_store = :memory_store

require 'helpers/activejob_helpers'

RSpec.configure do |config|
  config.use_transactional_fixtures = true
  config.file_fixture_path = 'spec/fixtures'
  config.filter_run focus: true
  config.run_all_when_everything_filtered = true
  config.include ActiveSupport::Testing::TimeHelpers
  config.include FactoryGirl::Syntax::Methods
  config.include RSpec::Rails::Matchers::ActiveJob

  config.before(:suite) do
    FactoryGirl.find_definitions
  end
end
