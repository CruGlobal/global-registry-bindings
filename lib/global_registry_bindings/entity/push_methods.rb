# frozen_string_literal: true

require 'global_registry_bindings/workers/push_gr_entity_worker'

module GlobalRegistry #:nodoc:
  module Bindings #:nodoc:
    module Entity #:nodoc:
      module PushMethods
        extend ActiveSupport::Concern

        included do
          after_commit :async_push_entity_to_global_registry, on: (global_registry.push_on - %i[delete])
        end

        def async_push_entity_to_global_registry
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
          if global_registry.parent_is_self? && global_registry.parent_id_value.blank?
            # Push parent entity if it exists and is missing global_registry_id
            global_registry.parent&.create_entity_in_global_registry
          end
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

        def entity_attributes_to_push
          entity_attributes = self.class.columns_to_push.map do |name, type|
            value_for_global_registry(name, type)
          end.compact.to_h
          entity_attributes[:client_integration_id] = id unless global_registry.exclude_fields
                                                                               .include?(:client_integration_id)
          entity_attributes[:client_updated_at] = updated_at.to_s(:db) if respond_to?(:updated_at)
          entity_attributes[:parent_id] = global_registry.parent_id_value if global_registry.parent_is_self?
          entity_attributes
        end

        def value_for_global_registry(name, type)
          value = send(name)
          return [name, value] if value.nil?
          value = case type
                  when :datetime, :date
                    value.to_s(:db)
                  when :boolean
                    value ? 'true' : 'false'
                  else
                    value.to_s.strip
                  end
          [name, value]
        rescue NoMethodError
          nil
        end

        module ClassMethods
          def columns_to_push
            @columns_to_push ||= columns
                                 .collect { |c| { c.name.underscore.to_sym => normalize_column_type(c.type, c.name) } }
                                 .reduce(&:merge)
                                 .reject { |k, _v| global_registry.exclude_fields.include? k }
                                 .merge(global_registry.extra_fields)
          end

          protected

          def normalize_column_type(type, name)
            if type.to_s == 'text'
              :string
            elsif name.ends_with?('_id')
              :uuid
            else
              type
            end
          end
        end
      end
    end
  end
end
