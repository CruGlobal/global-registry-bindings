# frozen_string_literal: true

require 'global_registry'
require 'global_registry_bindings/workers/delete_entity_worker'

module GlobalRegistry #:nodoc:
  module Bindings #:nodoc:
    module Entity #:nodoc:
      module PushRelationshipMethods
        extend ActiveSupport::Concern

        def relationship
          global_registry_relationship(type)
        end

        def push_relationship_to_global_registry
          # Delete relationship if it exists and the related id_value is missing
          if relationship.related.nil? && relationship.related_id_value.nil? && relationship.id_value
            delete_relationship_from_global_registry(false)
            return
          end
          ensure_related_entities_have_global_registry_ids!
          push_global_registry_relationship_type
          create_relationship_in_global_registry
        end

        def create_relationship_in_global_registry
          entity = put_relationship_to_global_registry
          relationship.id_value = global_registry_relationship_entity_id_from_entity entity
          model.update_column( # rubocop:disable Rails/SkipsModelValidations
            relationship.id_column,
            relationship.id_value
          )
        end

        def global_registry_relationship_entity_id_from_entity(entity)
          relationships = Array.wrap entity.dig(
            'entity',
            relationship.primary_type.to_s,
            "#{relationship.related_relationship_name}:relationship"
          )
          relationships.detect do |rel|
            cid = rel['client_integration_id']
            cid = cid['value'] if cid.is_a?(Hash)
            cid == relationship.client_integration_id.to_s
          end&.dig('relationship_entity_id')
        end

        def ensure_related_entities_have_global_registry_ids!
          return if relationship.primary_id_value && relationship.related_id_value
          # Enqueue push_entity worker for related entities missing global_registry_id and retry relationship push
          names = []
          unless relationship.primary_id_value
            names << push_primary_to_global_registry
          end
          unless relationship.related_id_value
            names << push_related_to_global_registry
          end
          raise GlobalRegistry::Bindings::RelatedEntityMissingGlobalRegistryId,
                "#{model.class.name}(#{model.id}) has related entities [#{names.compact.join ', '}] missing " \
                'global_registry_id; will retry.'
        end

        def push_primary_to_global_registry
          model = relationship.primary
          if relationship.primary_binding == :entity
            model.push_entity_to_global_registry_async
          else
            model.push_relationships_to_global_registry_async(relationship.primary_binding)
          end
          "#{model.class.name}(#{model.id})"
        end

        def push_related_to_global_registry
          model = relationship.related
          model.push_entity_to_global_registry_async
          "#{model.class.name}(#{model.id})"
        end

        def relationship_entity
          { entity: { relationship.primary_type => {
            "#{relationship.related_relationship_name}:relationship" =>
              model.relationship_attributes_to_push(type)
                   .merge(relationship.related_type =>
                         relationship.related_id_value)
          }, client_integration_id: relationship.primary.id } }
        end

        def put_relationship_to_global_registry
          GlobalRegistry::Entity.put(
            relationship.primary_id_value,
            relationship_entity,
            params: {
              full_response: true,
              fields: "#{relationship.related_relationship_name}:relationship"
            }
          )
        rescue RestClient::BadRequest => e
          response = JSON.parse(e.response.body)
          raise unless response['error'] =~ /^Validation failed:.*already exists$/i
          # Delete relationship entity and retry on 400 Bad Request (client_integration_id already exists)
          delete_relationship_from_global_registry
        end

        def delete_relationship_from_global_registry(and_retry = true)
          GlobalRegistry::Bindings::Workers::DeleteEntityWorker.new.perform(relationship.id_value)
          model.update_column( # rubocop:disable Rails/SkipsModelValidations
            relationship.id_column, nil
          )
          return unless and_retry
          raise GlobalRegistry::Bindings::RelatedEntityExistsWithCID,
                "#{model.class.name}(#{model.id}) #{relationship.related_relationship_name}" \
                ':relationship already exists with client_integration_id(' \
                "#{relationship.client_integration_id}). Will delete and retry."
        end
      end
    end
  end
end
