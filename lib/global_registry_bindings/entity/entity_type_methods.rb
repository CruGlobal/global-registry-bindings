# frozen_string_literal: true

require "global_registry"

module GlobalRegistry # :nodoc:
  module Bindings # :nodoc:
    module Entity # :nodoc:
      module EntityTypeMethods
        extend ActiveSupport::Concern

        def push_entity_type_to_global_registry
          return unless global_registry_entity.ensure_type?
          parent_entity_id = parent_entity_type_id
          entity_type = Rails.cache.fetch(entity_type_cache_key, expires_in: 1.hour) do
            GlobalRegistry::EntityType.get("filters[name]" => global_registry_entity.type,
              "filters[parent_id]" => parent_entity_id)["entity_types"]&.first
          end

          entity_type ||= GlobalRegistry::EntityType.post(entity_type: {name: global_registry_entity.type,
                                                                        parent_id: parent_entity_id,
                                                                        field_type: "entity"})["entity_type"]

          push_entity_type_fields_to_global_registry(entity_type)
          entity_type
        end

        private

        def push_entity_type_fields_to_global_registry(entity_type)
          existing_fields = entity_type["fields"]&.collect { |f| f["name"].to_sym } || []
          model.entity_columns_to_push
            .except(*existing_fields)
            .each do |name, type|
            GlobalRegistry::EntityType.post(entity_type: {name: name,
                                                          parent_id: entity_type["id"],
                                                          field_type: type})
          end
        end

        def parent_entity_type_id
          parent = global_registry_entity&.parent
          return if parent.blank? || global_registry_entity.parent_is_self?
          worker = GlobalRegistry::Bindings::Workers::PushEntityWorker.new parent
          parent_entity_type = worker.send :push_entity_type_to_global_registry
          parent_entity_type&.dig("id")
        end

        def entity_type_cache_key
          "GlobalRegistry::Bindings::EntityType::#{global_registry_entity.type}"
        end
      end
    end
  end
end
