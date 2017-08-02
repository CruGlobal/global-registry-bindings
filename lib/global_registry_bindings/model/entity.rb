# frozen_string_literal: true

module GlobalRegistry #:nodoc:
  module Bindings #:nodoc:
    module Model #:nodoc:
      module Entity
        extend ActiveSupport::Concern

        def entity_attributes_to_push
          entity_attributes = entity_columns_to_push.map do |name, type|
            value_for_global_registry(name, type)
          end.compact.to_h
          entity_attributes[:client_integration_id] = id unless global_registry_entity.exclude_fields
                                                                                      .include?(:client_integration_id)
          entity_attributes[:client_updated_at] = updated_at.to_s(:db) if respond_to?(:updated_at)
          if global_registry_entity.parent_is_self?
            entity_attributes[:parent_id] = global_registry_entity.parent_id_value
          end
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

        def entity_columns_to_push
          @columns_to_push ||= if global_registry_entity.include_all_columns?
                                 self
                                   .class
                                   .columns
                                   .collect do |c|
                                   { c.name.underscore.to_sym => normalize_entity_column_type(c.type, c.name) }
                                 end # rubocop:disable Style/MultilineBlockChain
                                   .reduce(&:merge)
                                   .reject { |k, _v| global_registry_entity.exclude_fields.include? k }
                                   .merge(global_registry_entity.extra_fields)
                               else
                                 global_registry_entity.extra_fields
                               end
        end

        protected

        def normalize_entity_column_type(type, name)
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
