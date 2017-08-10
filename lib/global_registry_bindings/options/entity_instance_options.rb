# frozen_string_literal: true

module GlobalRegistry #:nodoc:
  module Bindings #:nodoc:
    module Options
      class EntityInstanceOptions
        delegate :id_column,
                 :mdm_id_column,
                 :mdm_timeout,
                 :push_on,
                 :mdm_worker_class_name,
                 :ensure_type?,
                 :include_all_columns?,
                 to: :@class_options

        def initialize(model)
          @model = model
          @class_options = model.class.global_registry_entity
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

        def type
          t = @class_options.type
          t.is_a?(Proc) ? t.call(@model) : t
        end

        def parent
          @model.send(@class_options.parent) if @class_options.parent.present?
        end

        def parent_class
          return if @class_options.parent.blank?
          @class_options.parent_class
        end

        def parent_type
          parent&.global_registry_entity&.type
        end

        def parent_id_value
          parent&.global_registry_entity&.id_value
        end

        def parent_required?
          @class_options.parent.present? && !parent_is_self?
        end

        def parent_is_self?
          @class_options.parent.present? && parent_class == @model.class
        end

        def exclude
          option = @class_options.exclude
          case option
          when Proc
            option.call(type, @model)
          when Symbol
            @model.send(option, type)
          else
            option
          end
        end

        def fields
          option = @class_options.fields
          case option
          when Proc
            option.call(type, @model)
          when Symbol
            @model.send(option, type)
          else
            option
          end
        end
      end
    end
  end
end
