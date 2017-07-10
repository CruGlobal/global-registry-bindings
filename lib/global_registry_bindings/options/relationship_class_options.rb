# frozen_string_literal: true

require 'ostruct'

module GlobalRegistry #:nodoc:
  module Bindings #:nodoc:
    module Options
      class RelationshipClassOptions
        delegate :id_column,
                 :type,
                 :push_on,
                 :primary_association,
                 :primary_association_class,
                 :primary_association_foreign_key,
                 :primary_relationship_name,
                 :related_association,
                 :related_association_class,
                 :related_association_foreign_key,
                 :related_relationship_name,
                 :exclude_fields,
                 :extra_fields, to: :@options

        def initialize(type, model_class)
          @model_class = model_class
          @options = OpenStruct.new model_class._global_registry_bindings_options[:relationships][type]
        end
      end
    end
  end
end
