# frozen_string_literal: true

require 'ostruct'

module GlobalRegistry #:nodoc:
  module Bindings #:nodoc:
    module Options
      class ClassOptions
        delegate :id_column,
                 :mdm_id_column,
                 :mdm_timeout,
                 :type,
                 :push_on,
                 :parent_association,
                 :exclude_fields,
                 :extra_fields, to: :@options

        def initialize(model_class)
          @model_class = model_class
          @options = OpenStruct.new model_class.global_registry_bindings_options
        end

        def parent_class
          return if parent_association.blank?
          @model_class.reflect_on_all_associations
                      .detect { |a| a.name == parent_association.to_sym }
              &.klass
        end

        def parent_is_self?
          parent_association.present? && parent_type == type
        end

        def parent_type
          parent_class&.global_registry&.type
        end

        def mdm_worker_class_name
          "Pull#{@model_class.name.tr(':', '')}MdmIdWorker"
        end
      end
    end
  end
end
