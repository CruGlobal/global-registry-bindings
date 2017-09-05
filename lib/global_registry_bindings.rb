# frozen_string_literal: true

require 'active_support/lazy_load_hooks'
require 'global_registry_bindings/global_registry_bindings'
require 'global_registry_bindings/railtie' if defined? ::Rails::Railtie

module GlobalRegistry
  module Bindings
    def self.configure
      yield self
    end

    def self.sidekiq_options
      @sidekiq_options ||= {}
    end

    def self.sidekiq_options=(opts)
      @sidekiq_options = opts
    end
  end
end

ActiveSupport.on_load(:active_record) do
  ActiveRecord::Base.send :extend, GlobalRegistry::Bindings
end
