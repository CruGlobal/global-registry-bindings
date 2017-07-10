# frozen_string_literal: true

module GlobalRegistry #:nodoc:
  module Bindings #:nodoc:
    module Options
      class RelationshipOptionsParser
        def initialize(model_class)
          @model_class = model_class
        end

        def defaults
          {
            id_column: :global_registry_id,
            type: @model_class.name.demodulize.underscore.to_sym,
            push_on: %i[create update delete],
            primary_association: nil,
            primary_association_class: nil,
            primary_relationship_name: nil,
            related_association: nil,
            related_association_class: nil,
            related_relationship_name: nil,
            exclude_fields: %i[id created_at updated_at],
            extra_fields: {}
          }.freeze
        end

        def parse(options_hash = {})
          merge_defaults options_hash
          update_association_classes
          update_foreign_keys
          update_excludes
          @options
        end

        private

        def merge_defaults(options_hash = {})
          @options = defaults.merge(options_hash) do |key, oldval, newval|
            if key == :exclude_fields
              case newval
              when Proc, Symbol
                newval
              else
                oldval.concat Array.wrap(newval)
              end
            else
              newval
            end
          end
        end

        def update_association_classes
          unless @options[:primary_association_class]
            @options[:primary_association_class] = association_class @options[:primary_association]
          end
          unless @options[:related_association_class] # rubocop:disable Style/GuardClause
            @options[:related_association_class] = association_class @options[:related_association]
          end
        end

        def update_foreign_keys
          unless @options[:primary_association_foreign_key]
            @options[:primary_association_foreign_key] = association_foreign_key @options[:primary_association]
          end
          unless @options[:related_association_foreign_key] # rubocop:disable Style/GuardClause
            @options[:related_association_foreign_key] = association_foreign_key @options[:related_association]
          end
        end

        def update_excludes
          return unless @options[:exclude_fields].is_a? Array
          @options[:exclude_fields] << @options[:id_column]
          @options[:exclude_fields] << @options[:mdm_id_column] if @options[:mdm_id_column].present?

          if @options[:primary_association_foreign_key]
            @options[:exclude_fields] << @options[:primary_association_foreign_key]
          end
          if @options[:related_association_foreign_key] # rubocop:disable Style/GuardClause
            @options[:exclude_fields] << @options[:related_association_foreign_key]
          end
        end

        def validate_options; end

        def association_foreign_key(name)
          @model_class.reflect_on_association(name)&.foreign_key&.to_sym
        end

        def association_class(name)
          @model_class.reflect_on_association(name)&.klass
        end
      end
    end
  end
end