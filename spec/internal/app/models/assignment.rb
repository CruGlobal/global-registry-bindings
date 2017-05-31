# frozen_string_literal: true

class Assignment < ApplicationRecord
  belongs_to :person, class_name: 'Namespaced::Person'
  belongs_to :organization
  global_registry_bindings parent_association: :person,
                           related_association: :organization,
                           parent_relationship_name: :person,
                           related_relationship_name: :fancy_org
end
