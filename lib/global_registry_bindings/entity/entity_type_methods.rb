# frozen_string_literal: true

require 'global_registry'

module GlobalRegistry #:nodoc:
  module Bindings #:nodoc:
    module Entity #:nodoc:
      module EntityTypeMethods
        extend ActiveSupport::Concern

        module ClassMethods
          def push_entity_type
            parent_entity_id = parent_entity_type_id
            entity_type = Rails.cache.fetch(entity_type_cache_key, expires_in: 1.hour) do
              GlobalRegistry::EntityType.get('filters[name]' => global_registry.type,
                                             'filters[parent_id]' => parent_entity_id)['entity_types']&.first
            end

            unless entity_type
              entity_type = GlobalRegistry::EntityType.post(entity_type: { name: global_registry.type,
                                                                           parent_id: parent_entity_id,
                                                                           field_type: 'entity' })['entity_type']
            end
            push_entity_type_fields(entity_type)
            entity_type
          end

          def push_entity_type_fields(entity_type)
            existing_fields = entity_type['fields']&.collect { |f| f['name'].to_sym } || []
            columns_to_push
              .reject { |k, _v| existing_fields.include? k }
              .each do |name, type|
              GlobalRegistry::EntityType.post(entity_type: { name: name,
                                                             parent_id: entity_type['id'],
                                                             field_type: type })
            end
          end

          def parent_entity_type_id
            parent_type = global_registry&.parent_type
            return if parent_type.blank?
            parent_entity_type = global_registry.parent_class.send :push_entity_type
            parent_entity_type&.dig('id')
          end

          def entity_type_cache_key
            "GlobalRegistry::Bindings::EntityType::#{global_registry.type}"
          end
        end
      end
    end
  end
end
