# frozen_string_literal: true

module GlobalRegistry #:nodoc:
  module Bindings #:nodoc:
    module Options
      class EntityOptionsParser
        def initialize(model_class)
          @model_class = model_class
        end

        def defaults
          {
            id_column: :global_registry_id,
            mdm_id_column: nil,
            type: @model_class.name.demodulize.underscore.to_sym,
            push_on: %i[create update delete],
            parent_association: nil,
            parent_association_class: nil,
            related_association: nil,
            related_association_class: nil,
            parent_relationship_name: nil,
            related_relationship_name: nil,
            exclude_fields: %i[id created_at updated_at],
            extra_fields: {},
            mdm_timeout: 1.minute
          }.freeze
        end

        def parse(options_hash = {})
          merge_defaults options_hash
          update_association_classes
          update_excludes
          validate_options
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
          unless @options[:parent_association_class]
            @options[:parent_association_class] = association_class @options[:parent_association]
          end
          unless @options[:related_association_class] # rubocop:disable Style/GuardClause
            @options[:related_association_class] = association_class @options[:related_association]
          end
        end

        def update_excludes
          return unless @options[:exclude_fields].is_a? Array
          @options[:exclude_fields] << @options[:id_column]
          @options[:exclude_fields] << @options[:mdm_id_column] if @options[:mdm_id_column].present?

          parent_id_column = association_foreign_key @options[:parent_association]
          @options[:exclude_fields] << parent_id_column.to_sym if parent_id_column

          related_id_column = association_foreign_key @options[:related_association]
          @options[:exclude_fields] << related_id_column.to_sym if related_id_column
        end

        def validate_options; end

        def association_foreign_key(name)
          @model_class.reflect_on_all_associations.detect { |a| a.name == name }&.foreign_key if name
        end

        def association_class(name)
          @model_class.reflect_on_all_associations.detect { |a| a.name == name }&.klass if name
        end
      end
    end
  end
end
