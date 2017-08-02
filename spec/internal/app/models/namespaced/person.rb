# frozen_string_literal: true

module Namespaced
  class Person < ApplicationRecord
    has_many :addresses, dependent: :destroy, inverse_of: :person
    has_many :assignments
    has_many :organizations, through: :assignments
    belongs_to :country_of_service,
               class_name: 'Country',
               foreign_key: :country_of_service_id,
               inverse_of: :employees
    belongs_to :country_of_residence,
               class_name: 'Country',
               foreign_key: :country_of_residence_id,
               inverse_of: :residents

    global_registry_bindings binding: :entity,
                             mdm_id_column: :global_registry_mdm_id,
                             mdm_timeout: 24.hours,
                             exclude_fields: %i[guid country_of_service_gr_id country_of_service_id
                                                country_of_residence_gr_id country_of_residence_id]

    global_registry_bindings binding: :relationship,
                             type: :country_of_service,
                             id_column: :country_of_service_gr_id,
                             client_integration_id: ->(model) { "cos_#{model.id}" },
                             related_association: :country_of_service,
                             exclude_fields: :exclude_cos_fields,
                             extra_fields: :extra_cos_fields,
                             ensure_relationship_type: false,
                             rename_entity_type: false,
                             include_all_columns: false

    global_registry_bindings binding: :relationship,
                             type: :country_of_residence,
                             id_column: :country_of_residence_gr_id,
                             client_integration_id: ->(model) { "cor_#{model.id}" },
                             related_association: :country_of_residence,
                             ensure_relationship_type: false,
                             rename_entity_type: false,
                             include_all_columns: false

    def entity_attributes_to_push
      entity_attributes = super
      entity_attributes[:authentication] = { key_guid: guid }
      entity_attributes
    end

    def exclude_cos_fields(_type)
      %i[]
    end

    def extra_cos_fields(_type)
      {}
    end

    def relationship_attributes_to_push(type)
      entity_attributes = super(type)
      case type
      when :country_of_service
        entity_attributes[:country_of_service] = true
      when :country_of_residence
        entity_attributes[:country_of_residence] = true
      end
      entity_attributes
    end
  end
end
