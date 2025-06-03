# frozen_string_literal: true

require "rubygems"
require "bundler/setup"
require "pry"

require "active_record"
ActiveRecord::Migration.verbose = false

require "combustion"
Combustion.initialize! :active_record

require "rspec/rails"
require "webmock/rspec"
require "factory_girl"
require "simplecov"

require "global_registry_bindings"
require "global_registry_bindings/testing"

require "sidekiq/testing"
require "sidekiq_unique_jobs/testing"
Sidekiq::Testing.fake!

require "mock_redis"
MOCK_REDIS = MockRedis.new

ActionController::Base.cache_store = :memory_store

require "helpers/sidekiq_helpers"

RSpec.configure do |config|
  config.use_transactional_fixtures = true
  config.file_fixture_path = "spec/fixtures"
  config.filter_run focus: true
  config.run_all_when_everything_filtered = true
  config.include ActiveSupport::Testing::TimeHelpers
  config.include FactoryGirl::Syntax::Methods
  config.include SidekiqHelpers

  config.before(:suite) do
    FactoryGirl.find_definitions
  end

  config.before(:each) do
    allow(Sidekiq).to receive(:redis).and_yield(MOCK_REDIS)

    clear_sidekiq_jobs_and_locks

    Rails.cache.clear
  end
end

# The mock_redis gem mocks the redis gem for all intents and purposes.
# Newer versions of sidekiq do not use the redis gem though. They use redis-client.
# This monkeypatch makes sure that the mock_redis gem works with sidekiq 8.0.0 and later.
# It is not needed for sidekiq 6.x and earlier.

Rails.application.config.after_initialize do
  class MockRedis
    module ZsetMethods
      def zscan(key, cursor, opts = {})
        opts = cursor.merge(key: lambda { |x| x[0] })
        result = common_scan(zrange(key, 0, -1, withscores: true), 0, opts)
        hash_result = {}
        result[1].each do |item|
          hash_result[item[0]] = item[1]
        end
        hash_result
      end
    end
  end
end
