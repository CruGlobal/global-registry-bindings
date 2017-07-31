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
                 :primary_association,
                 :primary_association_class,
                 :primary_association_foreign_key,
                 :primary_relationship_name,
                 :related_association,
                 :related_association_class,
                 :related_association_foreign_key,
                 :related_association_type,
                 :related_relationship_name,
                 :related_global_registry_id,
                 :exclude_fields,
                 :extra_fields, to: :@options

        def initialize(type, model_class)
          @model_class = model_class
          @options = OpenStruct.new model_class._global_registry_bindings_options[:relationships][type]
        end

        def ensure_relationship_type?
          @options.ensure_relationship_type.present?
        end

        def rename_entity_type?
          @options.rename_entity_type.present?
        end
      end
    end
  end
end
