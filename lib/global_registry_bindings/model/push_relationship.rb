# frozen_string_literal: true

require 'global_registry_bindings/workers/push_relationship_worker'

module GlobalRegistry #:nodoc:
  module Bindings #:nodoc:
    module Model #:nodoc:
      module PushRelationship
        extend ActiveSupport::Concern

        included do
          after_commit :push_relationship_to_global_registry_async, on: %i[create update]
        end

        def push_relationship_to_global_registry_async(type = nil)
          types = type ? Array.wrap(type) : changed_relationship_types
          types.each do |t|
            ::GlobalRegistry::Bindings::Workers::PushRelationshipWorker.perform_async(self.class, id, t)
          end
        end

        def changed_relationship_types
          types = []
          self.class.global_registry_relationship_types.each do |type|
            pfk = global_registry_relationship(type).primary_association_foreign_key
            rfk = global_registry_relationship(type).related_association_foreign_key
            # TODO: maybe need to inspect change to determine if deleted
            types << type if previous_changes.key?(pfk) || previous_changes.key?(rfk)
          end
          types
        end
      end
    end
  end
end
