# frozen_string_literal: true

class Address < ActiveRecord::Base
  belongs_to :person, inverse_of: :addresses
  global_registry_bindings parent_association: :person,
                           exclude_fields: %i[address1],
                           extra_fields: { line1: :string, line2: :string, postal_code: :string }

  alias_attribute :line1, :address1
  alias_attribute :postal_code, :zip

  # def entity_attributes_to_push
  #   entity_attributes = super
  #   entity_attributes[:line1] = address1
  #   entity_attributes[:postal_code] = zip
  #   entity_attributes
  # end
end
