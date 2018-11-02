# frozen_string_literal: true

class Assignment < ApplicationRecord
  belongs_to :person, class_name: 'Namespaced::Person'
  belongs_to :organization
  belongs_to :assigned_by, class_name: 'Namespaced::Person', foreign_key: 'assigned_by_id'

  global_registry_bindings binding: :relationship,
                           type: :fancy_org_assignment,
                           primary: :person,
                           related: :organization,
                           include_all_columns: true,
                           exclude: %i[assigned_by_id assigned_by_gr_rel_id],
                           job: {queue: :default}

  global_registry_bindings binding: :relationship,
                           type: :assigned_by,
                           id_column: :assigned_by_gr_rel_id,
                           primary_binding: :fancy_org_assignment,
                           primary_name: :assigned_by,
                           related: :assigned_by,
                           job: {queue: :default}
end
