# frozen_string_literal: true

require 'active_support/lazy_load_hooks'
require 'global_registry_bindings/global_registry_bindings'
require 'global_registry_bindings/railtie' if defined? ::Rails::Railtie

module GlobalRegistry
  module Bindings
    def self.configure
      yield self
    end

    def self.activejob_options
      @activejob_options ||= {}
    end

    def self.activejob_options=(opts)
      @activejob_options = opts
    end

    def self.queues
      @queues ||= {}
    end

    def self.queues=(opts)
      if opts.is_a? String
        @queues = { default: opts }
      elsif opts.is_a? Hash
        @queues = opts
      else
        raise ArgumentError,
              'config.queues in GlobalRegistry::Bindings must be a queue name (String) of a map of queues (Hash)'
      end
    end

    def self.runtime_error_action
      @runtime_error_action ||= :log
    end

    def self.runtime_error_action=(action)
      action = :log unless %i[ignore log raise].include? action
      @runtime_error_action = action
    end

    def self.resolve_activejob_options(options_spec)
      opts = activejob_options.merge(options_spec || {})
      opts[:queue] = resolve_queue_name(opts[:queue])
      opts.delete_if { |_, v| v.nil? }
    end

    def self.resolve_queue_name(queue_spec)
      if queue_spec.blank?
        raise ArgumentError, 'Cannot determine default queue name' if queues.blank?
        queue_spec = :default
      end
      if queue_spec.is_a?(Symbol) && queues.any?
        raise ArgumentError, "Cannot resolve queue name from #{queue_spec}" if queues[queue_spec].nil?
        queues[queue_spec]
      else
        queue_spec
      end
    end
  end
end

ActiveSupport.on_load(:active_record) do
  ActiveRecord::Base.send :extend, GlobalRegistry::Bindings
end
