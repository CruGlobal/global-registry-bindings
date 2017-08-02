# frozen_string_literal: true

class Area < ApplicationRecord
  has_many :organizations

  global_registry_bindings include_all_columns: false,
                           extra_fields: { area_name: :string, area_code: :string, is_active: :boolean }
end
