# frozen_string_literal: true

module GlobalRegistry #:nodoc:
  module Bindings #:nodoc:
    module Entity #:nodoc:
      module PushEntityMethods
        extend ActiveSupport::Concern

        def push_entity_to_global_registry # rubocop:disable Metrics/PerceivedComplexity
          return if global_registry_entity.parent_required? && global_registry_entity.parent.blank?
          push_entity_type_to_global_registry

          if global_registry_entity.parent_type.present? && !global_registry_entity.parent_is_self?
            create_dependent_entity_in_global_registry
          elsif global_registry_entity.id_value?
            update_entity_in_global_registry
          else
            create_entity_in_global_registry
          end
        rescue RestClient::ResourceNotFound
          global_registry_entity.id_value = nil
          push_entity_to_global_registry
        end

        def update_entity_in_global_registry
          entity_attributes = { global_registry_entity.type => model.entity_attributes_to_push }
          GlobalRegistry::Entity.put(global_registry_entity.id_value, entity: entity_attributes)
        end

        def create_entity_in_global_registry
          ensure_parent_entity_has_global_registry_id! if global_registry_entity.parent.present?
          entity_attributes = { global_registry_entity.type => model.entity_attributes_to_push }
          entity = GlobalRegistry::Entity.post(entity: entity_attributes)
          global_registry_entity.id_value = dig_global_registry_id_from_entity(entity['entity'],
                                                                               global_registry_entity.type)
          model.update_column(global_registry_entity.id_column, # rubocop:disable Rails/SkipsModelValidations
                              global_registry_entity.id_value)
        end

        # Create or Update a child entity (ex: :email_address is a child of :person)
        def create_dependent_entity_in_global_registry # rubocop:disable Metrics/AbcSize
          return if global_registry_entity.parent.blank?
          ensure_parent_entity_has_global_registry_id!
          entity_attributes = {
            global_registry_entity.parent_type => {
              client_integration_id: global_registry_entity.parent.id,
              global_registry_entity.type => model.entity_attributes_to_push
            }
          }
          entity = GlobalRegistry::Entity.put(global_registry_entity.parent_id_value, entity: entity_attributes)
          global_registry_entity.id_value = dig_global_registry_id_from_entity(entity['entity'],
                                                                               global_registry_entity.type,
                                                                               global_registry_entity.parent_type)
          model.update_column(global_registry_entity.id_column, # rubocop:disable Rails/SkipsModelValidations
                              global_registry_entity.id_value)
        end

        def dig_global_registry_id_from_entity(entity, type, parent_type = nil)
          return entity&.dig(type.to_s, 'id') unless parent_type
          Array.wrap(entity&.dig(parent_type.to_s, type.to_s)).detect do |item|
            item['client_integration_id'] == model.id.to_s
          end&.dig('id')
        end

        def ensure_parent_entity_has_global_registry_id!
          return unless (global_registry_entity.parent_is_self? && global_registry_entity.parent_id_value.blank?) ||
                        global_registry_entity.parent_id_value.blank?
          # Push parent entity if it exists and is missing global_registry_id
          global_registry_entity.parent.push_entity_to_global_registry_async
          raise GlobalRegistry::Bindings::ParentEntityMissingGlobalRegistryId,
                "#{model.class.name}(#{model.id}) has parent entity " \
                "#{global_registry_entity.parent.class.name}(#{global_registry_entity.parent.id}) missing " \
                'global_registry_id; will retry.'
        end
      end
    end
  end
end
