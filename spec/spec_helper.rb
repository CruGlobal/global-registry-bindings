# frozen_string_literal: true

require 'rubygems'
require 'bundler/setup'
require 'pry'

require 'active_record'
ActiveRecord::Migration.verbose = false

require 'combustion'
Combustion.initialize! :active_record do
  if config.active_record.sqlite3.respond_to?(:represent_boolean_as_integer)
    config.active_record.sqlite3.represent_boolean_as_integer = true
  end
end

require 'rspec/rails'
require 'webmock/rspec'
require 'factory_girl'
require 'simplecov'

require 'global_registry_bindings'
require 'global_registry_bindings/testing'

require 'sidekiq/testing'
require 'sidekiq_unique_jobs/testing'
Sidekiq::Testing.fake!

require 'mock_redis'
MOCK_REDIS = MockRedis.new

ActionController::Base.cache_store = :memory_store

require 'helpers/sidekiq_helpers'

RSpec.configure do |config|
  config.use_transactional_fixtures = true
  config.file_fixture_path = 'spec/fixtures'
  config.filter_run focus: true
  config.run_all_when_everything_filtered = true
  config.include ActiveSupport::Testing::TimeHelpers
  config.include FactoryGirl::Syntax::Methods
  config.include SidekiqHelpers

  config.before(:suite) do
    FactoryGirl.find_definitions
  end

  config.before(:each) do
    SidekiqUniqueJobs.configure do |c|
      c.redis_test_mode = :mock
    end
    allow(Sidekiq).to receive(:redis).and_yield(MOCK_REDIS)

    clear_sidekiq_jobs_and_locks

    Rails.cache.clear
  end
end
