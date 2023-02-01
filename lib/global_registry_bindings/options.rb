# frozen_string_literal: true

require "global_registry_bindings/options/entity_instance_options"
require "global_registry_bindings/options/entity_class_options"
require "global_registry_bindings/options/relationship_instance_options"
require "global_registry_bindings/options/relationship_class_options"

module GlobalRegistry # :nodoc:
  module Bindings # :nodoc:
    module Options
      extend ActiveSupport::Concern

      included do
        # Entity Class Options
        class_attribute :_global_registry_bindings_class_options
        self._global_registry_bindings_class_options ||=
          GlobalRegistry::Bindings::Options::EntityClassOptions.new(self)
        # Relationship Class Options
        class_attribute :_global_registry_bindings_class_relationships
        self._global_registry_bindings_class_relationships = {}
      end

      def global_registry_entity
        @_global_registry_bindings_instance_options ||=
          GlobalRegistry::Bindings::Options::EntityInstanceOptions.new(self)
      end

      def global_registry_relationship(type)
        @_global_registry_bindings_instance_relationships ||= {}
        @_global_registry_bindings_instance_relationships[type] ||=
          GlobalRegistry::Bindings::Options::RelationshipInstanceOptions.new(type, self)
      end

      module ClassMethods
        def global_registry_entity
          _global_registry_bindings_class_options
        end

        def global_registry_relationship(type)
          _global_registry_bindings_class_relationships[type] ||=
            GlobalRegistry::Bindings::Options::RelationshipClassOptions.new(type, self)
        end

        def global_registry_relationship_types
          _global_registry_bindings_options[:relationships].keys
        end
      end
    end
  end
end
