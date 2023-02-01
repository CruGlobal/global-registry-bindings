# frozen_string_literal: true

require "global_registry"

GlobalRegistry.configure do |config|
  config.access_token = "fake"
  config.base_url = "https://backend.global-registry.org"
end
