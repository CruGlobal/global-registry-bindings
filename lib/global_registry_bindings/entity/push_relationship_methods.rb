# frozen_string_literal: true

require 'global_registry'

module GlobalRegistry #:nodoc:
  module Bindings #:nodoc:
    module Entity #:nodoc:
      module PushRelationshipMethods
        extend ActiveSupport::Concern

        def push_relationship_to_global_registry
          ensure_related_entities_have_global_registry_ids!
          push_global_registry_relationship_type

          if global_registry.id_value?
            update_relationship_in_global_registry
          else
            create_relationship_in_global_registry
          end
        end

        def update_relationship_in_global_registry
          GlobalRegistry::Entity.put(global_registry.id_value, entity: model.entity_attributes_to_push)
        end

        def create_relationship_in_global_registry # rubocop:disable Metrics/AbcSize
          entity = GlobalRegistry::Entity.put(global_registry.parent_id_value,
                                              { entity:  { global_registry.parent_type => {
                                                "#{global_registry.related_relationship_name}:relationship" =>
                                                  model.entity_attributes_to_push.merge(global_registry.related_type =>
                                                                                    global_registry.related_id_value)
                                              }, client_integration_id: global_registry.parent.id } },
                                              params: {
                                                full_response: true,
                                                fields: "#{global_registry.related_relationship_name}:relationship"
                                              })
          global_registry.id_value = global_registry_relationship_entity_id_from_entity entity
          model.update_column(global_registry.id_column, # rubocop:disable Rails/SkipsModelValidations
                              global_registry.id_value)
          # Update relationship to work around bug in Global Registry
          # - If current system doesn't own a copy of the parent entity, then creating a new relationship in the same
          #   request will not add the relationship entity_type properties.
          update_relationship_in_global_registry if global_registry.id_value?
        end

        def global_registry_relationship_entity_id_from_entity(entity)
          relationships = Array.wrap entity.dig('entity', global_registry.parent_type.to_s,
                                                "#{global_registry.related_relationship_name}:relationship")
          relationships.detect do |rel|
            cid = rel['client_integration_id']
            cid = cid['value'] if cid.is_a?(Hash)
            cid == model.id.to_s
          end&.dig('relationship_entity_id')
        end

        def ensure_related_entities_have_global_registry_ids! # rubocop:disable Metrics/AbcSize
          return if global_registry.parent_id_value.present? && global_registry.related_id_value.present?
          # Enqueue push_entity worker for related entities missing global_registry_id and retry relationship push
          names = []
          [global_registry.parent, global_registry.related].each do |model|
            next if model.global_registry.id_value?
            names << "#{model.class.name}(#{model.id})"
            model.push_entity_to_global_registry_async
          end
          raise GlobalRegistry::Bindings::RelatedEntityMissingGlobalRegistryId,
                "#{model.class.name}(#{model.id}) has related entities [#{names.join ', '}] missing " \
                'global_registry_id; will retry.'
        end
      end
    end
  end
end
