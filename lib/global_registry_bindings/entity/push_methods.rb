# frozen_string_literal: true

require 'global_registry_bindings/workers/push_gr_entity_worker'

module GlobalRegistry #:nodoc:
  module Bindings #:nodoc:
    module Entity #:nodoc:
      module PushMethods
        extend ActiveSupport::Concern

        included do
          after_commit :async_push_entity_to_global_registry, on: %i[create update]
          # after_commit :delete_from_global_registry, on: :destroy
        end

        def async_push_entity_to_global_registry
          ::GlobalRegistry::Bindings::Workers::PushGrEntityWorker.perform_async(self.class, id)
        end

        def push_entity_to_global_registry
          self.class.push_entity_type

          if global_registry_id_value
            update_entity_in_global_registry
          else
            create_entity_in_global_registry
          end
        rescue RestClient::ResourceNotFound
          self.global_registry_id_value = nil
          push_entity_to_global_registry
        end

        def update_entity_in_global_registry; end

        def create_entity_in_global_registry; end

        module ClassMethods
          protected

          def columns_to_push
            @columns_to_push ||= columns
                                 .collect { |c| { c.name.underscore.to_sym => normalize_column_type(c.type, c.name) } }
                                 .reduce(&:merge)
                                 .reject { |k, _v| global_registry_bindings_options[:exclude_fields].include? k }
                                 .merge(global_registry_bindings_options[:extra_fields])
          end

          def normalize_column_type(type, name)
            if type.to_s == 'text'
              :string
            elsif name.ends_with?('_id')
              :uuid
            else
              type
            end
          end

          def value_for_global_registry(column_name, value)
            return value if value.blank?

            column = columns_to_push.detect { |c| c[:name] == column_name }
            return unless column

            case column[:field_type].to_s
            when 'datetime', 'date'
              value.to_s(:db)
            when 'boolean'
              value ? 'true' : 'false'
            else
              value.to_s.strip
            end
          end
        end
      end
    end
  end
end
