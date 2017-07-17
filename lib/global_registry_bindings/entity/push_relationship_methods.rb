# frozen_string_literal: true

require 'global_registry'
require 'global_registry_bindings/workers/delete_entity_worker'

module GlobalRegistry #:nodoc:
  module Bindings #:nodoc:
    module Entity #:nodoc:
      module PushRelationshipMethods
        extend ActiveSupport::Concern

        def push_relationship_to_global_registry
          ensure_related_entities_have_global_registry_ids!
          push_global_registry_relationship_type
          create_relationship_in_global_registry
        end

        def create_relationship_in_global_registry
          entity = put_relationship_to_global_registry
          global_registry_relationship(type).id_value = global_registry_relationship_entity_id_from_entity entity
          model.update_column( # rubocop:disable Rails/SkipsModelValidations
            global_registry_relationship(type).id_column,
            global_registry_relationship(type).id_value
          )
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
            cid == global_registry_relationship(type).client_integration_id.to_s
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

        def put_relationship_to_global_registry
          GlobalRegistry::Entity.put(
            global_registry_relationship(type).primary_id_value,
            relationship_entity,
            params: {
              full_response: true,
              fields: "#{global_registry_relationship(type).related_relationship_name}:relationship"
            }
          )
        rescue RestClient::BadRequest => e
          response = JSON.parse(e.response.body)
          raise unless response['error'] =~ /^Validation failed:.*already exists$/i
          # Delete relationship entity and retry on 400 Bad Request (client_integration_id already exists)
          delete_relationship_from_global_registry_and_retry
        end

        def delete_relationship_from_global_registry_and_retry
          GlobalRegistry::Bindings::Workers::DeleteEntityWorker.new.perform(global_registry_relationship(type).id_value)
          model.update_column( # rubocop:disable Rails/SkipsModelValidations
            global_registry_relationship(type).id_column, nil
          )
          raise GlobalRegistry::Bindings::RelatedEntityExistsWithCID,
                "#{model.class.name}(#{model.id}) #{global_registry_relationship(type).related_relationship_name}" \
                ':relationship already exists with client_integration_id(' \
                "#{global_registry_relationship(type).client_integration_id}). Will delete and retry."
        end
      end
    end
  end
end
