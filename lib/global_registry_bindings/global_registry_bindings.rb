# frozen_string_literal: true

require 'active_support/core_ext'
require 'global_registry'
require 'global_registry_bindings/exceptions'
require 'global_registry_bindings/options'
require 'global_registry_bindings/entity/entity_methods'
require 'global_registry_bindings/entity/entity_type_methods'
require 'global_registry_bindings/entity/relationship_type_methods'
require 'global_registry_bindings/entity/push_entity_methods'
require 'global_registry_bindings/entity/delete_entity_methods'
require 'global_registry_bindings/entity/mdm_methods'
require 'global_registry_bindings/entity/push_relationship_methods'

module GlobalRegistry #:nodoc:
  module Bindings #:nodoc:
    # Call this in your model to enable and configure Global Registry bindings.
    #
    # Options:
    #
    # * `:id_column`: Column used to track the Global Registry ID for the model instance. Can be a :string or :uuid
    #   column. (default: `:global_registry_id`)
    # * `:mdm_id_column`: Column used to enable MDM tracking and set the name of the column. MDM is disabled when this
    #    option is nil or empty. (default: `nil`)
    # * `:type`: Global Registry entity type. Default value is underscored name of the model.
    # * `:push_on`: Array of Active Record lifecycle events used to push changes to Global Registry.
    #    (default: `[:create, :update, :delete]`)
    # * `:parent_association`: Name of the Active Record parent association. Must be defined before calling
    #    global_registry_bindings in order to determine foreign_key field. (default: `nil`)
    # * `:parent_association_class`: Class name of the parent model. Required if `:parent_association` can not be used
    #    to determine the parent class. This can happen if parent is defined by another gem, like `has_ancestry`.
    #    (default: `nil`)
    # * `:related_association`: Name of the Active Record related association. Setting this option changes the
    #    global registry binding from entity to relationship. Active Record association must be defined before calling
    #    global_registry_bindings in order to determine the foreign key. `:parent_relationship_name` and
    #    `:related_relationship_name` must be set for relationship binding to work. (default: `nil`)
    # * `:related_association_class`: Class name of the related model. Required if `:related_association` can not be
    #    used to determine the related class. (default: `nil`)
    # * `:parent_relationship_name`: Name of parent relationship role. (default: `nil`)
    # * `:related_relationship_name`: Name of the related relationship role. (default: `nil`)
    # * `:exclude_fields`: Model fields to exclude when pushing to Global Registry. Will additionally include
    #   `:mdm_id_column` and `:parent_association` foreign key when defined.
    #   (default:  `[:id, :created_at, :updated_at, :global_registry_id]`)
    # * `:extra_fields`: Additional fields to send to Global Registry. This should be a hash with name as the key
    #    and :type attributes as the value. Ex: `{language: :string}`. Name is a symbol and type is an ActiveRecord
    #    column type.
    # * `:mdm_timeout`: Only pull mdm information at most once every `:mdm_timeout`. (default: `1.minute`)
    #
    # @api public
    def global_registry_bindings(options = {})
      global_registry_bindings_parse_options! options

      include Options
      include Entity::EntityMethods
      if global_registry.push_on.any? { |item| %i[create update].include? item }
        if global_registry.related_association && global_registry.parent_association
          include Entity::RelationshipTypeMethods
          include Entity::PushRelationshipMethods
        else
          include Entity::EntityTypeMethods
          include Entity::PushEntityMethods
        end
      end

      include Entity::DeleteEntityMethods if global_registry.push_on.include? :delete
      include Entity::MdmMethods if global_registry.mdm_id_column.present?
    end

    private

    def global_registry_bindings_parse_options!(options)
      class_attribute :_global_registry_bindings_options_hash
      self._global_registry_bindings_options_hash = GlobalRegistry::Bindings::OptionsParser.new(self).parse(options)
    end
  end
end
