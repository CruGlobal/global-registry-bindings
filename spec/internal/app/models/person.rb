# frozen_string_literal: true

class Person < ApplicationRecord
  has_many :addresses, dependent: :destroy, inverse_of: :person

  global_registry_bindings mdm_id_column: :global_registry_mdm_id,
                           exclude_fields: %i[guid]

  def entity_attributes_to_push
    entity_attributes = super
    entity_attributes[:authentication] = { key_guid: guid }
    entity_attributes
  end
end
