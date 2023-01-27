# frozen_string_literal: true

require "global_registry_bindings/worker"
require "global_registry_bindings/entity/relationship_type_methods"
require "global_registry_bindings/entity/push_relationship_methods"

module GlobalRegistry # :nodoc:
  module Bindings # :nodoc:
    module Workers # :nodoc:
      class PushRelationshipWorker < GlobalRegistry::Bindings::Worker
        include GlobalRegistry::Bindings::Entity::RelationshipTypeMethods
        include GlobalRegistry::Bindings::Entity::PushRelationshipMethods
        sidekiq_options unique: :until_and_while_executing

        attr_accessor :type

        def initialize(model = nil, type = nil)
          super model
          self.type = type.to_sym if type
        end

        def perform(model_class, id, type)
          super model_class, id
          self.type = type.to_sym
          push_relationship_to_global_registry
        rescue ActiveRecord::RecordNotFound # rubocop:disable Lint/HandleExceptions
          # If the record was deleted after the job was created, swallow it
        end
      end
    end
  end
end
