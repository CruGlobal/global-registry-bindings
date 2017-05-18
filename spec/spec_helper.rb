# frozen_string_literal: true

require 'rubygems'
require 'bundler/setup'
require 'pry'

require 'active_record'
ActiveRecord::Migration.verbose = false

require 'combustion'
Combustion.initialize! :active_record

require 'rspec/rails'
require 'webmock/rspec'
require 'factory_girl'
require 'simplecov'

require 'global_registry_bindings'

require 'sidekiq/testing'
require 'sidekiq_unique_jobs/testing'
Sidekiq::Testing.fake!

require 'mock_redis'
MOCK_REDIS = MockRedis.new

ActionController::Base.cache_store = :memory_store

RSpec.configure do |config|
  config.use_transactional_fixtures = true
  config.file_fixture_path = 'spec/fixtures'
  config.include FactoryGirl::Syntax::Methods

  config.before(:suite) do
    FactoryGirl.find_definitions
  end

  config.before(:each) do
    MOCK_REDIS.keys.each do |key|
      MOCK_REDIS.del(key)
    end

    Sidekiq::Queues.clear_all
    Sidekiq::Worker.clear_all

    SidekiqUniqueJobs.configure do |c|
      c.redis_test_mode = :mock
    end
    allow(Sidekiq).to receive(:redis).and_yield(MOCK_REDIS)

    Rails.cache.clear
  end
end
