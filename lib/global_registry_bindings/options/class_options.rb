# frozen_string_literal: true

require 'ostruct'

module GlobalRegistry #:nodoc:
  module Bindings #:nodoc:
    module Options
      class ClassOptions
        delegate :id_column,
                 :mdm_id_column,
                 :type,
                 :mdm_timeout,
                 :push_on,
                 :parent_association,
                 :parent_association_class,
                 :related_association,
                 :related_association_class,
                 :parent_relationship_name,
                 :related_relationship_name,
                 :exclude_fields,
                 :extra_fields, to: :@options

        def initialize(model_class)
          @model_class = model_class
          @options = OpenStruct.new model_class._global_registry_bindings_options_hash
        end

        def mdm_worker_class_name
          "Pull#{@model_class.name.tr(':', '')}MdmIdWorker"
        end
      end
    end
  end
end
