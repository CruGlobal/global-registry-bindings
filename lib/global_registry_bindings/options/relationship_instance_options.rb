# frozen_string_literal: true

module GlobalRegistry #:nodoc:
  module Bindings #:nodoc:
    module Options
      class RelationshipInstanceOptions
        delegate :id_column,
                 :push_on,
                 :primary_association,
                 :primary_association_class,
                 :primary_association_foreign_key,
                 :primary_relationship_name,
                 :related_association,
                 :related_association_class,
                 :related_association_foreign_key,
                 :related_relationship_name,
                 to: :@class_options

        def initialize(type, model)
          @model = model
          @class_options = model.class.global_registry_relationship(type)
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

        def primary
          @model.send(primary_association) if primary_association.present?
        end

        def primary_class
          return if primary_association.blank?
          primary_association_class
        end

        def primary_type
          primary&.global_registry_entity&.type
        end

        def primary_id_value
          primary&.global_registry_entity&.id_value
        end

        def primary_required?
          primary_association.present? && related_association.blank? && !primary_is_self?
        end

        def primary_is_self?
          primary_association.present? && primary_class == @model.class
        end

        def primary_relationship_name
          @class_options.primary_relationship_name || primary_type
        end

        def related
          @model.send(related_association) if related_association.present?
        end

        def related_type
          related&.global_registry_entity&.type
        end

        def related_id_value
          related&.global_registry_entity&.id_value
        end

        def related_relationship_name
          @class_options.related_relationship_name || related_type
        end

        def exclude_fields
          option = @class_options.exclude_fields
          case option
          when Proc
            option.call(type, @model)
          when Symbol
            @model.send(option, type)
          else
            option
          end
        end

        def extra_fields
          option = @class_options.extra_fields
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
