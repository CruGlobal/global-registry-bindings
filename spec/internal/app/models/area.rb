# frozen_string_literal: true

class Area < ApplicationRecord
  has_many :organizations

  global_registry_bindings
end
