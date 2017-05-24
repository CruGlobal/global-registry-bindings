# frozen_string_literal: true

require 'active_support/core_ext'
require 'global_registry'
require 'global_registry_bindings/options'
require 'global_registry_bindings/entity/entity_type_methods'
require 'global_registry_bindings/entity/push_methods'
require 'global_registry_bindings/entity/delete_methods'
require 'global_registry_bindings/entity/mdm_methods'

module GlobalRegistry #:nodoc:
  module Bindings #:nodoc:
    # Call this in your model to enable and configure Global Registry bindings.
    #
    # Options:
    #
    # - :id_column - Column used to track the Global Registry ID for the model instance.
    #   Can be a :string or :uuid column. Default value 'global_registry_id'
    # - :mdm_id_column - Column used to enable MDM tracking and set the name of the column. MDM is disabled
    #   when this option is nil or empty. Default value nil.
    # - :type - Global Registry entity type name. Default value is underscored name of the model.
    # - :push_on - Array of Active Record lifecycle events used to push changes to Global Registry.
    #   Default: [:create, :update, :delete]
    # - :parent_association - Name of the Active Record parent association. Must be defined before calling
    #   global_registry_bindings. Default: nil
    # - :exclude_fields - Model fields to skip when pushing to Global Registry. Default value [:id, :created_at,
    #   :updated_at, :global_registry_id] (global_registry_id will be whatever value is used for :id_column)
    # - :extra_fields - Additional fields to send to Global Registry. This should be a hash with name as the key
    #   and :type attributes as the value. Ex: {language: :string}. Name is a symbol and type is an ActiveRecord
    #   column type.
    #
    # @api public
    def global_registry_bindings(options = {})
      global_registry_bindings_parse_options! options

      include Options
      if global_registry.push_on.any? { |item| %i[create update].include? item }
        include Entity::EntityTypeMethods
        include Entity::PushMethods
      end
      include Entity::DeleteMethods if global_registry.push_on.include? :delete
      include Entity::MdmMethods if global_registry.mdm_id_column.present?
    end

    private

    def global_registry_bindings_default_options
      {
        id_column: :global_registry_id,
        mdm_id_column: nil,
        type: to_s.underscore.to_sym,
        push_on: %i[create update delete],
        parent_association: nil,
        exclude_fields: %i[id created_at updated_at],
        extra_fields: {}
      }.freeze
    end

    def global_registry_bindings_parse_options!(options)
      options = global_registry_bindings_default_options.deep_merge(options) do |key, oldval, newval|
        if :exclude_fields == key
          oldval.concat Array.wrap(newval)
        else
          newval
        end
      end
      options = global_registry_bindings_update_exclude_fields(options)

      class_attribute :global_registry_bindings_options
      self.global_registry_bindings_options = options
    end

    def global_registry_bindings_update_exclude_fields(options)
      options[:exclude_fields] << options[:id_column]
      options[:exclude_fields] << options[:mdm_id_column] if options[:mdm_id_column].present?
      if options[:parent_association].present?
        parent_id_column = reflect_on_all_associations
                           .detect { |a| a.name == options[:parent_association] }
                               &.foreign_key
        options[:exclude_fields] << parent_id_column.to_sym if parent_id_column
      end
      options
    end
  end
end
