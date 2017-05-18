# frozen_string_literal: true

class Default < ActiveRecord::Base
  self.table_name = :people
  global_registry_bindings
end
