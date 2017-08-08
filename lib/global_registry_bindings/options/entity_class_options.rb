# frozen_string_literal: true

require 'ostruct'

module GlobalRegistry #:nodoc:
  module Bindings #:nodoc:
    module Options
      class EntityClassOptions
        delegate :id_column,
                 :mdm_id_column,
                 :type,
                 :mdm_timeout,
                 :push_on,
                 :parent_association,
                 :parent_association_class,
                 :exclude,
                 :fields, to: :@options

        def initialize(model_class)
          @model_class = model_class
          @options = OpenStruct.new model_class._global_registry_bindings_options[:entity]
        end

        def ensure_entity_type?
          @options.ensure_entity_type.present?
        end

        def include_all_columns?
          @options.include_all_columns.present?
        end

        def mdm_worker_class_name
          "Pull#{@model_class.name.tr(':', '')}MdmIdWorker"
        end
      end
    end
  end
end
