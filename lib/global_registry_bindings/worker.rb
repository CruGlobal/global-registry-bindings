# frozen_string_literal: true

require 'sidekiq'
require 'sidekiq-unique-jobs'

module GlobalRegistry #:nodoc:
  module Bindings #:nodoc:
    class Worker
      include Sidekiq::Worker

      attr_accessor :model
      delegate :global_registry, to: :model

      def initialize(model = nil)
        self.model = model
      end

      def perform(model_class, id)
        klass = model_class.is_a?(String) ? model_class.constantize : model_class
        self.model = klass.find(id)
      end
    end
  end
end
