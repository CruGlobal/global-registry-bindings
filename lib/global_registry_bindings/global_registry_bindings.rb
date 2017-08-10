# frozen_string_literal: true

require 'active_support/core_ext'
require 'global_registry'
require 'global_registry_bindings/exceptions'
require 'global_registry_bindings/options'
require 'global_registry_bindings/options/entity_options_parser'
require 'global_registry_bindings/options/relationship_options_parser'
require 'global_registry_bindings/model/entity'
require 'global_registry_bindings/model/push_entity'
require 'global_registry_bindings/model/push_relationship'
require 'global_registry_bindings/model/delete_entity'
require 'global_registry_bindings/model/pull_mdm'
require 'global_registry_bindings/model/relationship'
require 'global_registry_bindings/worker'

module GlobalRegistry #:nodoc:
  module Bindings #:nodoc:
    def global_registry_bindings(options = {})
      options[:binding] ||= :entity
      unless method_defined? :_global_registry_bindings_options
        class_attribute :_global_registry_bindings_options
        self._global_registry_bindings_options = { entity: nil, relationships: {} }
      end
      if options[:binding] == :entity
        global_registry_bindings_entity options
      elsif options[:binding] == :relationship
        global_registry_bindings_relationship options
      else
        raise ArgumentError, ':binding option must be :entity or :relationship'
      end
    end

    private

    def global_registry_bindings_entity(options = {})
      if _global_registry_bindings_options[:entity].present?
        raise '#global_registry_bindings with :entity binding called more than once.'
      end
      _global_registry_bindings_options[:entity] = GlobalRegistry::Bindings::Options::EntityOptionsParser.new(self)
                                                                                                         .parse(options)
      include Options unless respond_to? :global_registry_entity
      global_registry_bindings_entity_includes
    end

    def global_registry_bindings_relationship(options = {})
      options = GlobalRegistry::Bindings::Options::RelationshipOptionsParser.new(self).parse(options)
      _global_registry_bindings_options[:relationships][options[:type]] = options

      include Options unless respond_to? :global_registry_entity
      global_registry_bindings_relationship_includes(options[:type])
    end

    def global_registry_bindings_entity_includes
      include Model::Entity
      if global_registry_entity.push_on.any? { |item| %i[create update].include? item }
        include Model::PushEntity
      end

      include Model::DeleteEntity if global_registry_entity.push_on.include? :destroy
      include Model::PullMdm if global_registry_entity.mdm_id_column.present?
    end

    def global_registry_bindings_relationship_includes(_type)
      include Model::Relationship
      include Model::PushRelationship
    end
  end
end
