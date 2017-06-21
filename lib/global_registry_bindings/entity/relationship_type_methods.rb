# frozen_string_literal: true

require 'global_registry'

module GlobalRegistry #:nodoc:
  module Bindings #:nodoc:
    module Entity #:nodoc:
      module RelationshipTypeMethods
        extend ActiveSupport::Concern

        def push_global_registry_relationship_type # rubocop:disable Metrics/MethodLength
          parent_entity_type_id, related_entity_type_id = associated_entity_ids

          relationship_type = Rails.cache.fetch(relationship_type_cache_key, expires_in: 1.hour) do
            GlobalRegistry::RelationshipType.get(
              'filters[between]' => "#{parent_entity_type_id},#{related_entity_type_id}"
            )['relationship_types'].detect do |r|
              r['relationship1']['relationship_name'] == global_registry.parent_relationship_name.to_s
            end
          end

          unless relationship_type
            relationship_type =
              GlobalRegistry::RelationshipType.post(relationship_type: {
                                                      entity_type1_id: parent_entity_type_id,
                                                      entity_type2_id: related_entity_type_id,
                                                      relationship1: global_registry.parent_relationship_name,
                                                      relationship2: global_registry.related_relationship_name
                                                    })['relationship_type']
          end
          push_global_registry_relationship_type_fields(relationship_type)
          relationship_type
        end

        def associated_entity_ids
          parent_worker = GlobalRegistry::Bindings::Workers::PushEntityWorker.new global_registry.parent
          related_worker = GlobalRegistry::Bindings::Workers::PushEntityWorker.new global_registry.related
          [parent_worker.send(:push_entity_type_to_global_registry)&.dig('id'),
           related_worker.send(:push_entity_type_to_global_registry)&.dig('id')]
        end

        def push_global_registry_relationship_type_fields(relationship_type)
          existing_fields = relationship_type['fields']&.collect { |f| f['name'].to_sym } || []
          fields = model.entity_columns_to_push
                        .reject { |k, _v| existing_fields.include? k }
                        .map { |name, type| { name: name, field_type: type } }
          return if fields.empty?
          GlobalRegistry::RelationshipType.put(relationship_type['id'],
                                               relationship_type: { fields: fields })
        end

        def relationship_type_cache_key
          "GlobalRegistry::Bindings::RelationshipType::#{global_registry.parent_type}::" \
            "#{global_registry.related_type}::#{global_registry.parent_relationship_name}"
        end
      end
    end
  end
end
