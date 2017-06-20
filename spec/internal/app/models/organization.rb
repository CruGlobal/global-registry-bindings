# frozen_string_literal: true

class Organization < ApplicationRecord
  has_many :children, class_name: 'Organization', foreign_key: :parent_id
  belongs_to :parent, class_name: 'Organization'

  has_many :assignments
  global_registry_bindings id_column: :gr_id,
                           type: ->(_model) { :fancy_org },
                           push_on: %i[create delete],
                           parent_association: :parent,
                           exclude_fields: :exclude_gr_fields,
                           extra_fields: proc { |_type, _model| {} }

  def exclude_gr_fields(_type)
    %i[id created_at updated_at gr_id parent_id]
  end
end
