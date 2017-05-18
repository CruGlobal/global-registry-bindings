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
              GlobalRegistry::EntityType.get('filters[name]' => entity_type_name,
                                             'filters[parent_id]' => parent_entity_id)['entity_types']&.first
            end

            unless entity_type
              entity_type = GlobalRegistry::EntityType.post(entity_type: { name: entity_type_name,
                                                                           parent_id: parent_entity_id,
                                                                           field_type: 'entity' })['entity_type']
            end
            push_entity_type_fields(entity_type)
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
            parent_entity_type = parent_association_class&.entity_type_name
            return nil unless parent_entity_type
            ::GlobalRegistry::EntityType.get('filters[name]' => parent_entity_type)['entity_types'].first['id']
          end

          def parent_association_class
            return if global_registry_bindings_options[:parent_association].blank?
            reflect_on_all_associations
              .detect { |a| a.name == global_registry_bindings_options[:parent_association].to_sym }
                &.klass
          end

          def entity_type_cache_key
            "GlobalRegistry::Bindings::EntityType::#{entity_type_name}"
          end
        end
      end
    end
  end
end
