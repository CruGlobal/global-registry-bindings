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
            binding: :entity,
            id_column: :global_registry_id,
            mdm_id_column: nil,
            type: @model_class.name.demodulize.underscore.to_sym,
            push_on: %i[create update destroy],
            parent: nil,
            parent_class: nil,
            exclude: %i[id created_at updated_at],
            fields: {},
            include_all_columns: false,
            mdm_timeout: 1.minute,
            ensure_type: true,
            if: nil, unless: nil, job: {}
          }.freeze
        end

        def parse(options_hash = {})
          validate_options! options_hash
          merge_defaults options_hash
          update_association_classes
          update_excludes
          @options
        end

        private

        def validate_options!(options = {})
          unknown = options.keys - defaults.keys
          raise ArgumentError, "global-registry-bindings: Unknown options (#{unknown.join ', '})" unless unknown.empty?
        end

        def merge_defaults(options_hash = {})
          @options = defaults.merge(options_hash) do |key, oldval, newval|
            if key == :exclude
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
          unless @options[:parent_class] # rubocop:disable Style/GuardClause
            @options[:parent_class] = association_class @options[:parent]
          end
        end

        def update_excludes
          return unless @options[:exclude].is_a? Array
          @options[:exclude] << @options[:id_column]
          @options[:exclude] << @options[:mdm_id_column] if @options[:mdm_id_column].present?

          parent_id_column = association_foreign_key @options[:parent]
          @options[:exclude] << parent_id_column.to_sym if parent_id_column
        end

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
