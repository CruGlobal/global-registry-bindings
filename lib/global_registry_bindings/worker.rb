# frozen_string_literal: true

require 'sidekiq'
require 'sidekiq-unique-jobs'

module GlobalRegistry #:nodoc:
  module Bindings #:nodoc:
    class Worker
      include Sidekiq::Worker

      attr_accessor :model
      delegate :global_registry_entity, to: :model
      delegate :global_registry_relationship, to: :model

      def initialize(model = nil)
        self.model = model
      end

      def perform(model_class, id)
        klass = model_class.is_a?(String) ? model_class.constantize : model_class
        self.model = klass.find(id)
      end

      def self.perform_async(*args)
        # Set global sidekiq_options
        worker = set(GlobalRegistry::Bindings.sidekiq_options)
        if worker == self # sidekiq 4.x
          super(*args)
        else # sidekiq 5.x
          worker.perform_async(*args)
        end
      end
    end
  end
end
