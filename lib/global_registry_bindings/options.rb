# frozen_string_literal: true

require 'global_registry_bindings/options/instance_options'
require 'global_registry_bindings/options/class_options'

module GlobalRegistry #:nodoc:
  module Bindings #:nodoc:
    module Options
      extend ActiveSupport::Concern

      included do
        class_attribute :_global_registry_bindings_class_options
        self._global_registry_bindings_class_options ||= GlobalRegistry::Bindings::Options::ClassOptions.new(self)
      end

      def global_registry
        @_global_registry_bindings_instance_options ||= GlobalRegistry::Bindings::Options::InstanceOptions.new(self)
      end

      module ClassMethods
        def global_registry
          _global_registry_bindings_class_options
        end
      end
    end

    class OptionsParser
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
        @options = defaults.deep_merge(options_hash) do |key, oldval, newval|
          if key == :exclude_fields
            oldval.concat Array.wrap(newval)
          else
            newval
          end
        end
        update_excludes
        validate_options
        @options
      end

      private

      def update_excludes
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
    end
  end
end
