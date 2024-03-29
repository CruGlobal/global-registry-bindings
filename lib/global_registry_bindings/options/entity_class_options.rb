# frozen_string_literal: true

require "ostruct"

module GlobalRegistry # :nodoc:
  module Bindings # :nodoc:
    module Options
      class EntityClassOptions
        delegate :id_column,
          :mdm_id_column,
          :fingerprint_column,
          :type,
          :mdm_timeout,
          :push_on,
          :parent,
          :parent_class,
          :exclude,
          :fields,
          :if,
          :unless, to: :@options

        def initialize(model_class)
          @model_class = model_class
          @options = OpenStruct.new model_class._global_registry_bindings_options[:entity]
        end

        def ensure_type?
          @options.ensure_type.present?
        end

        def include_all_columns?
          @options.include_all_columns.present?
        end

        def mdm_worker_class_name
          "Pull#{@model_class.name.tr(":", "")}MdmIdWorker"
        end
      end
    end
  end
end
