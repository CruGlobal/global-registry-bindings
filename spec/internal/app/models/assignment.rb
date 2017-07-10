# frozen_string_literal: true

class Assignment < ApplicationRecord
  belongs_to :person, class_name: 'Namespaced::Person'
  belongs_to :organization

  global_registry_bindings binding: :relationship,
                           type: :assignment,
                           primary_association: :person,
                           related_association: :organization
end
