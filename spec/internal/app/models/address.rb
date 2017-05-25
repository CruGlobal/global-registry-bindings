# frozen_string_literal: true

class Address < ApplicationRecord
  belongs_to :person, class_name: 'Namespaced::Person', inverse_of: :addresses
  global_registry_bindings parent_association: :person,
                           exclude_fields: %i[address1],
                           extra_fields: { line1: :string, line2: :string, postal_code: :string }

  alias_attribute :line1, :address1
  alias_attribute :postal_code, :zip
end
