# frozen_string_literal: true

module GlobalRegistry #:nodoc:
  module Bindings #:nodoc:
    module Model #:nodoc:
      module Relationship
        extend ActiveSupport::Concern

        def relationship_attributes_to_push(type)
          entity_attributes = relationship_columns_to_push(type).map do |name, t|
            relationship_value_for_global_registry(name, t)
          end.compact.to_h
          unless global_registry_relationship(type).exclude_fields.include?(:client_integration_id)
            entity_attributes[:client_integration_id] = global_registry_relationship(type).client_integration_id
          end
          entity_attributes[:client_updated_at] = updated_at.to_s(:db) if respond_to?(:updated_at)
          entity_attributes
        end

        def relationship_value_for_global_registry(name, type)
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
        rescue ::NoMethodError
          nil
        end

        def relationship_columns_to_push(type)
          @relationship_columns_to_push ||= {}
          @relationship_columns_to_push[type] ||=
            relationship_entity_columns(type)
            .reject { |k, _v| global_registry_relationship(type).exclude_fields.include? k }
            .merge(global_registry_relationship(type).extra_fields)
        end

        protected

        def normalize_relationship_column_type(type, name)
          if type.to_s == 'text'
            :string
          elsif name.ends_with?('_id')
            :uuid
          else
            type
          end
        end

        def relationship_entity_columns(type)
          return {} if global_registry_relationship(type).primary_class_is_self?
          self.class
              .columns
              .collect do |c|
            { c.name.underscore.to_sym => normalize_relationship_column_type(c.type, c.name) }
          end
              .reduce(&:merge)
        end
      end
    end
  end
end
