# frozen_string_literal: true

class Community < ApplicationRecord
  global_registry_bindings ensure_entity_type: false,
                           include_all_columns: true,
                           exclude: %i[infobase_id infobase_gr_id]

  global_registry_bindings binding: :relationship,
                           type: :infobase_ministry,
                           id_column: :infobase_gr_id,
                           related_relationship_name: :ministry,
                           related_association_type: :ministry,
                           related_association_foreign_key: :infobase_id,
                           related_global_registry_id: :pull_infobase_global_registry_id

  def pull_infobase_global_registry_id(_type)
    '41f767fd-86f4-42e2-8d24-cbc3f697b794'
  end
end
