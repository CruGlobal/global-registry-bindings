# frozen_string_literal: true

module GlobalRegistry #:nodoc:
  module Bindings #:nodoc:
    module Options
      class InstanceOptions
        delegate :id_column,
                 :mdm_id_column,
                 :type,
                 :parent_association,
                 :exclude_fields,
                 :extra_fields,
                 :parent_class,
                 :parent_type,
                 :parent_is_self?,
                 to: :@class_options

        def initialize(model)
          @model = model
          @class_options = model.class.global_registry
        end

        def id_value
          @model.send id_column
        end

        def id_value=(value)
          @model.send "#{id_column}=", value
        end

        def id_value?
          @model.send "#{id_column}?"
        end

        def parent
          @model.send(parent_association) if parent_association.present?
        end

        def parent_id_value
          parent&.global_registry&.id_value
        end
      end
    end
  end
end
