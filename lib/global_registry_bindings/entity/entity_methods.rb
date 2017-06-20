# frozen_string_literal: true

require 'global_registry'

module GlobalRegistry #:nodoc:
  module Bindings #:nodoc:
    module Entity #:nodoc:
      module EntityMethods
        extend ActiveSupport::Concern

        def entity_attributes_to_push
          entity_attributes = columns_to_push.map do |name, type|
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
        rescue ::NoMethodError
          nil
        end

        def columns_to_push
          @columns_to_push ||= self
                               .class
                               .columns
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
