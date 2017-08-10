# frozen_string_literal: true

require 'ostruct'

module GlobalRegistry #:nodoc:
  module Bindings #:nodoc:
    module Options
      class RelationshipClassOptions
        delegate :id_column,
                 :type,
                 :push_on,
                 :client_integration_id,
                 :primary_binding,
                 :primary,
                 :primary_class,
                 :primary_foreign_key,
                 :primary_name,
                 :related,
                 :related_class,
                 :related_foreign_key,
                 :related_type,
                 :related_name,
                 :related_global_registry_id,
                 :exclude,
                 :fields, to: :@options

        def initialize(type, model_class)
          @model_class = model_class
          @options = OpenStruct.new model_class._global_registry_bindings_options[:relationships][type]
        end

        def ensure_type?
          @options.ensure_type.present?
        end

        def rename_entity_type?
          @options.rename_entity_type.present?
        end

        def include_all_columns?
          @options.include_all_columns.present?
        end
      end
    end
  end
end
