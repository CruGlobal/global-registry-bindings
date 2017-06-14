# frozen_string_literal: true

require 'global_registry_bindings/workers/push_gr_entity_worker'

module GlobalRegistry #:nodoc:
  module Bindings #:nodoc:
    module Entity #:nodoc:
      module PushEntityMethods
        extend ActiveSupport::Concern

        included do
          after_commit :push_entity_to_global_registry_async, on: (global_registry.push_on - %i[delete])
        end

        def push_entity_to_global_registry_async
          ::GlobalRegistry::Bindings::Workers::PushGrEntityWorker.perform_async(self.class, id)
        end

        def push_entity_to_global_registry
          self.class.push_entity_type

          if global_registry.parent_type.present? && !global_registry.parent_is_self?
            create_dependent_entity_in_global_registry
          elsif global_registry.id_value?
            update_entity_in_global_registry
          else
            create_entity_in_global_registry
          end
        rescue RestClient::ResourceNotFound
          global_registry.id_value = nil
          push_entity_to_global_registry
        end

        def update_entity_in_global_registry
          entity_attributes = { global_registry.type => entity_attributes_to_push }
          GlobalRegistry::Entity.put(global_registry.id_value, entity: entity_attributes)
        end

        def create_entity_in_global_registry
          ensure_parent_entity_has_global_registry_id! if global_registry.parent.present?
          entity_attributes = { global_registry.type => entity_attributes_to_push }
          entity = GlobalRegistry::Entity.post(entity: entity_attributes)
          global_registry.id_value = dig_global_registry_id_from_entity(entity['entity'], global_registry.type)
          update_column(global_registry.id_column, # rubocop:disable Rails/SkipsModelValidations
                        global_registry.id_value)
        end

        # Create or Update a child entity (ex: :email_address is a child of :person)
        def create_dependent_entity_in_global_registry # rubocop:disable Metrics/AbcSize
          return if global_registry.parent.blank?
          global_registry.parent.push_entity_to_global_registry if global_registry.parent_id_value.blank?
          entity_attributes = {
            global_registry.parent_type => {
              client_integration_id: global_registry.parent.id,
              global_registry.type => entity_attributes_to_push
            }
          }
          entity = GlobalRegistry::Entity.put(global_registry.parent_id_value, entity: entity_attributes)
          global_registry.id_value = dig_global_registry_id_from_entity(entity['entity'],
                                                                        global_registry.type,
                                                                        global_registry.parent_type)
          update_column(global_registry.id_column, # rubocop:disable Rails/SkipsModelValidations
                        global_registry.id_value)
        end

        def dig_global_registry_id_from_entity(entity, type, parent_type = nil)
          return entity&.dig(type.to_s, 'id') unless parent_type
          Array.wrap(entity&.dig(parent_type.to_s, type.to_s)).detect do |item|
            item['client_integration_id'] == id.to_s
          end&.dig('id')
        end

        def ensure_parent_entity_has_global_registry_id!
          return unless global_registry.parent_is_self? && global_registry.parent_id_value.blank?
          # Push parent entity if it exists and is missing global_registry_id
          global_registry.parent.push_entity_to_global_registry_async
          raise GlobalRegistry::Bindings::ParentEntityMissingGlobalRegistryId,
                "#{self.class.name}(#{id}) has parent entity " \
                "#{global_registry.parent.class.name}(#{global_registry.parent.id}) missing " \
                'global_registry_id; will retry.'
        end
      end
    end
  end
end
