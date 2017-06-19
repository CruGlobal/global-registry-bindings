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

        def parent_class
          return if parent_association.blank?
          return parent_association_class if parent_association_class.present?
          @model_class.reflect_on_all_associations
                      .detect { |a| a.name == parent_association.to_sym }
              &.klass
        end

        def related_class
          return if related_association.blank?
          return related_association_class if related_association_class.present?
          @model_class.reflect_on_all_associations
                      .detect { |a| a.name == related_association.to_sym }
            &.klass
        end

        def parent_is_self?
          parent_association.present? && parent_type == type
        end

        def parent_type
          parent_class&.global_registry&.type
        end

        def related_type
          related_class&.global_registry&.type
        end

        def mdm_worker_class_name
          "Pull#{@model_class.name.tr(':', '')}MdmIdWorker"
        end
      end
    end
  end
end
