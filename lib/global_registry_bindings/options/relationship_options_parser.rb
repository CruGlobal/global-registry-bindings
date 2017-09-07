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
            binding: :relationship, id_column: :global_registry_id,
            type: @model_class.name.demodulize.underscore.to_sym,
            client_integration_id: :id,
            primary_binding: :entity, primary: nil, primary_class: nil, primary_name: nil, primary_foreign_key: nil,
            related: nil, related_class: nil, related_type: nil, related_name: nil, related_foreign_key: nil,
            related_global_registry_id: nil, related_binding: :entity,
            exclude: %i[id created_at updated_at], include_all_columns: false,
            fields: {}, ensure_type: true, rename_entity_type: true
          }.freeze
        end

        def parse(options_hash = {})
          validate_options! options_hash
          merge_defaults(options_hash)
          update_association_classes
          update_foreign_keys
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
          unless @options[:primary_class]
            @options[:primary_class] = if @options[:primary]
                                         association_class @options[:primary]
                                       else
                                         @model_class
                                       end
          end
          unless @options[:related_class] # rubocop:disable Style/GuardClause
            @options[:related_class] = association_class @options[:related]
          end
        end

        def update_foreign_keys
          unless @options[:primary_foreign_key]
            @options[:primary_foreign_key] = association_foreign_key @options[:primary]
          end
          unless @options[:related_foreign_key] # rubocop:disable Style/GuardClause
            @options[:related_foreign_key] = association_foreign_key @options[:related]
          end
        end

        def update_excludes
          return unless @options[:exclude].is_a? Array
          @options[:exclude] << @options[:id_column]
          @options[:exclude] << @options[:mdm_id_column] if @options[:mdm_id_column].present?

          if @options[:primary_foreign_key]
            @options[:exclude] << @options[:primary_foreign_key]
          end
          if @options[:related_foreign_key] # rubocop:disable Style/GuardClause
            @options[:exclude] << @options[:related_foreign_key]
          end
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
