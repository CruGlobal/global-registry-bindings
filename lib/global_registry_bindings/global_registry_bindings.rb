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
    # Call this in your model to enable and configure Global Registry bindings.
    #
    # Options:
    #
    # * `:binding`: Type of Global Registry binding. Either :entity or :relationship.
    #    (default: `:entity`)
    # * `:id_column`: Column used to track the Global Registry ID for the model instance. Can be a :string or :uuid
    #   column. (default: `:global_registry_id`)
    # * `:mdm_id_column`: Column used to enable MDM tracking and set the name of the column. MDM is disabled when this
    #    option is nil or empty. (default: `nil`)
    # * `:type`: Global Registry entity type. Accepts a Symbol or a Proc. Symbol is the name of the entity type, Proc
    #    is passed the model instance and must return a symbol which is the entity type. Default value is underscored
    #    name of the model. Ex: ```type: proc { |model| model.name.to_sym }```
    # * `:push_on`: Array of Active Record lifecycle events used to push changes to Global Registry.
    #    (default: `[:create, :update, :delete]`)
    # * `:parent_association`: Name of the Active Record parent association. Must be defined before calling
    #    global_registry_bindings in order to determine foreign_key for use in exclude_fields. (default: `nil`)
    # * `:parent_association_class`: Class name of the parent model. Required if `:parent_association` can not be used
    #    to determine the parent class. This can happen if parent is defined by another gem, like `ancestry`.
    #    (default: `nil`)
    # * `:related_association`: Name of the Active Record related association. Setting this option changes the
    #    global registry binding from entity to relationship. Active Record association must be defined before calling
    #    global_registry_bindings in order to determine the foreign key. `:parent_relationship_name` and
    #    `:related_relationship_name` must be set for relationship binding to work. (default: `nil`)
    # * `:related_association_class`: Class name of the related model. Required if `:related_association` can not be
    #    used to determine the related class. (default: `nil`)
    # * `:parent_relationship_name`: Name of parent relationship role. (default: `nil`)
    # * `:related_relationship_name`: Name of the related relationship role. (default: `nil`)
    # * `:exclude_fields`: Array, Proc or Symbol. Array of Model fields (as symbols) to exclude when pushing to Global
    #    Registry. Array Will additionally include `:mdm_id_column` and `:parent_association` foreign key when defined.
    #    If Proc, is passed type and model instance and should return an Array of the fields to exclude. If Symbol,
    #    this should be a method name the Model instance responds to. It is passed the type and should return an Array
    #    of fields to exclude. When Proc or Symbol are used, you must explicitly return the standard defaults.
    #   (default:  `[:id, :created_at, :updated_at, :global_registry_id]`)
    # * `:extra_fields`: Additional fields to send to Global Registry. Hash, Proc or Symbol. As a Hash, names are the
    #    keys and :type attributes are the values. Ex: `{language: :string}`. Name is a symbol and type is an
    #    ActiveRecord column type. As a Proc, it is passed the type and model instance, and should return a Hash.
    #    As a Symbol, the model should respond to this method, is passed the type, and should return a Hash.
    # * `:mdm_timeout`: Only pull mdm information at most once every `:mdm_timeout`. (default: `1.minute`)
    #
    # @api public
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

      include Model::DeleteEntity if global_registry_entity.push_on.include? :delete
      include Model::PullMdm if global_registry_entity.mdm_id_column.present?
    end

    def global_registry_bindings_relationship_includes(_type)
      include Model::Relationship
      include Model::PushRelationship
    end
  end
end
