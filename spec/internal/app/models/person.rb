# frozen_string_literal: true

class Person < ActiveRecord::Base
  has_many :addresses, dependent: :destroy, inverse_of: :person
  global_registry_bindings mdm_id_column: :global_registry_mdm_id
end
