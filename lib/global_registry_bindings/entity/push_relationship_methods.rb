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

          if global_registry_relationship(type).id_value?
            update_relationship_in_global_registry
          else
            create_relationship_in_global_registry
          end
        end

        def update_relationship_in_global_registry
          GlobalRegistry::Entity.put(global_registry_rel.id_value, entity: model.relationship_attributes_to_push(type))
        end

        def create_relationship_in_global_registry
          entity = GlobalRegistry::Entity.put(
            global_registry_relationship(type).primary_id_value,
            relationship_entity,
            params: {
              full_response: true,
              fields: "#{global_registry_relationship(type).related_relationship_name}:relationship"
            }
          )
          global_registry_relationship(type).id_value = global_registry_relationship_entity_id_from_entity entity
          model.update_column( # rubocop:disable Rails/SkipsModelValidations
            global_registry_relationship(type).id_column,
            global_registry_relationship(type).id_value
          )
          # Update relationship to work around bug in Global Registry
          # - If current system doesn't own a copy of the primary entity, then creating a new relationship in the same
          #   request will not add the relationship entity_type properties.
          update_relationship_in_global_registry if global_registry_relationship(type).id_value?
        end

        def global_registry_relationship_entity_id_from_entity(entity)
          relationships = Array.wrap entity.dig(
            'entity',
            global_registry_relationship(type).primary_type.to_s,
            "#{global_registry_relationship(type).related_relationship_name}:relationship"
          )
          relationships.detect do |rel|
            cid = rel['client_integration_id']
            cid = cid['value'] if cid.is_a?(Hash)
            cid == model.id.to_s
          end&.dig('relationship_entity_id')
        end

        def ensure_related_entities_have_global_registry_ids! # rubocop:disable Metrics/AbcSize
          if global_registry_relationship(type).primary_id_value.present? &&
             global_registry_relationship(type).related_id_value.present?
            return
          end
          # Enqueue push_entity worker for related entities missing global_registry_id and retry relationship push
          names = []
          [global_registry_relationship(type).primary, global_registry_relationship(type).related].each do |model|
            next if model.global_registry_entity.id_value?
            names << "#{model.class.name}(#{model.id})"
            model.push_entity_to_global_registry_async
          end
          raise GlobalRegistry::Bindings::RelatedEntityMissingGlobalRegistryId,
                "#{model.class.name}(#{model.id}) has related entities [#{names.join ', '}] missing " \
                'global_registry_id; will retry.'
        end

        def relationship_entity
          { entity:  { global_registry_relationship(type).primary_type => {
            "#{global_registry_relationship(type).related_relationship_name}:relationship" =>
              model.relationship_attributes_to_push(type)
                   .merge(global_registry_relationship(type).related_type =>
                         global_registry_relationship(type).related_id_value)
          }, client_integration_id: global_registry_relationship(type).primary.id } }
        end
      end
    end
  end
end
