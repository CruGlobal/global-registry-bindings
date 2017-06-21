# frozen_string_literal: true

require 'global_registry_bindings/workers/push_relationship_worker'

module GlobalRegistry #:nodoc:
  module Bindings #:nodoc:
    module Model #:nodoc:
      module PushRelationship
        extend ActiveSupport::Concern

        included do
          after_commit :push_relationship_to_global_registry_async, on: (global_registry.push_on - %i[delete])
        end

        def push_relationship_to_global_registry_async
          ::GlobalRegistry::Bindings::Workers::PushRelationshipWorker.perform_async(self.class, id)
        end
      end
    end
  end
end
