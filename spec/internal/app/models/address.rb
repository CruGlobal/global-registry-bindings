# frozen_string_literal: true

class Address < ApplicationRecord
  EXCLUDE_GR_FIELDS = %i[id created_at updated_at global_registry_id person_id address1].freeze
  belongs_to :person, class_name: 'Namespaced::Person', inverse_of: :addresses
  global_registry_bindings parent_association: :person,
                           exclude_fields: proc { |_type, _model| EXCLUDE_GR_FIELDS },
                           extra_fields: :global_registry_extra_fields

  alias_attribute :line1, :address1
  alias_attribute :postal_code, :zip

  def global_registry_extra_fields(_type)
    { line1: :string, line2: :string, postal_code: :string }
  end
end
