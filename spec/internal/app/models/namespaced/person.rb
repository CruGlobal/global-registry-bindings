# frozen_string_literal: true

module Namespaced
  class Person < ApplicationRecord
    has_many :addresses, dependent: :destroy, inverse_of: :person
    has_many :assignments

    global_registry_bindings mdm_id_column: :global_registry_mdm_id,
                             mdm_timeout: 24.hours,
                             exclude_fields: %i[guid]

    def entity_attributes_to_push
      entity_attributes = super
      entity_attributes[:authentication] = { key_guid: guid }
      entity_attributes
    end
  end
end
