# frozen_string_literal: true

class Default < ApplicationRecord
  self.table_name = :people
  global_registry_bindings
end
