# frozen_string_literal: true

class Address < ActiveRecord::Base
  belongs_to :person, inverse_of: :addresses
  global_registry_bindings parent_association: :person,
                           exclude_fields: %i[address1],
                           extra_fields: { line1: :string, postal_code: :string }
end
