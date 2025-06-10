# frozen_string_literal: true

require "global_registry_bindings/worker"
require "global_registry_bindings/entity/entity_type_methods"
require "global_registry_bindings/entity/push_entity_methods"

module GlobalRegistry # :nodoc:
  module Bindings # :nodoc:
    module Workers # :nodoc:
      class PushEntityWorker < GlobalRegistry::Bindings::Worker
        include GlobalRegistry::Bindings::Entity::EntityTypeMethods
        include GlobalRegistry::Bindings::Entity::PushEntityMethods
        sidekiq_options unique: :until_and_while_executing

        def perform(model_class, id)
          super
          push_entity_to_global_registry
        rescue ActiveRecord::RecordNotFound # rubocop:disable Lint/HandleExceptions
          # If the record was deleted after the job was created, swallow it
        end
      end
    end
  end
end
