# frozen_string_literal: true

require 'global_registry'

module GlobalRegistry #:nodoc:
  module Bindings #:nodoc:
    module Entity #:nodoc:
      module RelationshipTypeMethods
        extend ActiveSupport::Concern

        # rubocop:disable Metrics/MethodLength
        # rubocop:disable Metrics/AbcSize
        def push_global_registry_relationship_type
          puts "***************** global_registry_relationship(type).ensure_type? -- #{global_registry_relationship(type).ensure_type?} ********************"
          return unless global_registry_relationship(type).ensure_type?
          primary_entity_type_id = primary_associated_entity_type_id
          related_entity_type_id = related_associated_entity_type_id
          puts "================= primary_entity_type_id -- #{primary_entity_type_id} ----"
          puts "================= related_entity_type_id -- #{related_entity_type_id} ----"

          relationship_type = Rails.cache.fetch(relationship_type_cache_key, expires_in: 1.hour) do
            rel = GlobalRegistry::RelationshipType.get(
              'filters[between]' => "#{primary_entity_type_id},#{related_entity_type_id}"
            )['relationship_types'].detect do |r|
              r['relationship1']['relationship_name'] ==
                global_registry_relationship(type).primary_name.to_s
            end
            unless rel
              rel = GlobalRegistry::RelationshipType.post(
                relationship_type: {
                  entity_type1_id: primary_entity_type_id,
                  entity_type2_id: related_entity_type_id,
                  relationship1: global_registry_relationship(type).primary_name,
                  relationship2: global_registry_relationship(type).related_name
                }
              )['relationship_type']
              rename_relationship_entity_type(rel)
            end
            rel
          end
          push_global_registry_relationship_type_fields(relationship_type)
          relationship_type
        end
        # rubocop:enable Metrics/MethodLength
        # rubocop:enable Metrics/AbcSize

        def primary_associated_entity_type_id
          primary_worker = GlobalRegistry::Bindings::Workers::PushEntityWorker.new
          primary_worker.model = global_registry_relationship(type).primary
          entity_type = primary_worker.send(:push_entity_type_to_global_registry)
          puts "============ entity_type -- #{entity_type} --------"
          unless entity_type
            primary_type = global_registry_relationship(type).primary_type
            puts "============ primary_type -- #{primary_type} --------"
            entity_type = GlobalRegistry::EntityType.get(
              'filters[name]' => primary_type
            )['entity_types']&.first
          end
          entity_type&.dig('id')
        end

        def related_associated_entity_type_id
          puts "============ global_registry_relationship(type).related -- #{global_registry_relationship(type).related} --------"
          unless global_registry_relationship(type).related
            related_type = global_registry_relationship(type).related_type
            puts "============ related_type -- #{related_type} --------"
            # remote foreign_key doesn't have a model class in rails. Short-circuit and fetch entity_type by name
            entity_type = GlobalRegistry::EntityType.get(
              'filters[name]' => related_type
            )['entity_types']&.first
            unless entity_type
              raise GlobalRegistry::Bindings::RelatedEntityTypeMissing,
                    "#{model.class.name}(#{model.id}) has unknown related entity_type(#{related_type}) in " \
                    'global_registry. Entity Type must exist in Global Registry for remote foreign_key relationship.'
            end
            return entity_type&.dig('id')
          end
          related_worker = GlobalRegistry::Bindings::Workers::PushEntityWorker.new
          related_worker.model = global_registry_relationship(type).related
          related_worker.send(:push_entity_type_to_global_registry)&.dig('id')
        end

        def push_global_registry_relationship_type_fields(relationship_type)
          existing_fields = relationship_type['fields']&.collect { |f| f['name'].to_sym } || []
          fields = model.relationship_columns_to_push(type)
                        .reject { |k, _v| existing_fields.include? k }
                        .map { |name, type| { name: name, field_type: type } }
          return if fields.empty?
          relationship_type = GlobalRegistry::RelationshipType.put(relationship_type['id'],
                                                                   relationship_type: { fields: fields })
            &.dig('relationship_type')
          Rails.cache.write(relationship_type_cache_key, relationship_type, expires_in: 1.hour) if relationship_type
        end

        def rename_relationship_entity_type(relationship_type)
          return unless global_registry_relationship(type).rename_entity_type?
          entity_type_id = relationship_type&.dig('relationship_entity_type_id')
          GlobalRegistry::EntityType.put(entity_type_id, entity_type: { id: entity_type_id,
                                                                        name: global_registry_relationship(type).type })
        end

        def relationship_type_cache_key
          "GlobalRegistry::Bindings::RelationshipType::#{global_registry_relationship(type).primary_type}::" \
            "#{global_registry_relationship(type).related_type}::" \
            "#{global_registry_relationship(type).primary_name}"
        end
      end
    end
  end
end
