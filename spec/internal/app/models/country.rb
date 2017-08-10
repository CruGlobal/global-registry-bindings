# frozen_string_literal: true

class Country < ApplicationRecord
  has_many :employees, class_name: 'Namespaced::Person', inverse_of: :country_of_service
  has_many :residents, class_name: 'Namespaced::Person', inverse_of: :country_of_residence

  global_registry_bindings ensure_type: false, include_all_columns: true
end
