# frozen_string_literal: true

class Area < ApplicationRecord
  has_many :organizations

  global_registry_bindings fields: {area_name: :string, area_code: :string, is_active: :boolean}
end
