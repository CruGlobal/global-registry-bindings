# frozen_string_literal: true

# require 'sidekiq'
# require 'sidekiq-unique-jobs'

require 'active_job'

module GlobalRegistry #:nodoc:
  module Bindings #:nodoc:
    class Worker < ActiveJob::Base
      attr_accessor :model
      delegate :global_registry_entity, to: :model
      delegate :global_registry_relationship, to: :model

      def setup(model)
        self.model = model
      end

      def perform(model_class, id)
        klass = model_class.is_a?(String) ? model_class.constantize : model_class
        self.model = klass.find(id)
      end

      def self.perform_job(job_options, *args)
        activejob_options = GlobalRegistry::Bindings.resolve_activejob_options(job_options)
        worker = set(activejob_options)
        begin
          worker.perform_later(*args)
        rescue RuntimeError => e
          case GlobalRegistry::Bindings.runtime_error_action
          when :raise
            raise
          when :log
            ::Rollbar.error(e) if Module.const_defined? :Rollbar
          when :ignore
            return
          end
        end
      end
    end
  end
end
