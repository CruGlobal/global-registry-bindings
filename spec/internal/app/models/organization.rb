# frozen_string_literal: true

class Organization < ApplicationRecord
  has_many :children, class_name: 'Organization', foreign_key: :parent_id
  belongs_to :parent, class_name: 'Organization'

  has_many :assignments
  has_many :people, class_name: 'Namespaced::Person', through: :assignments

  belongs_to :area

  global_registry_bindings id_column: :gr_id,
                           type: ->(_model) { :fancy_org },
                           push_on: %i[create destroy],
                           parent_association: :parent,
                           exclude_fields: :exclude_gr_fields,
                           extra_fields: proc { |_type, _model| {} }

  global_registry_bindings binding: :relationship,
                           type: :area,
                           id_column: :global_registry_area_id,
                           related_association: :area,
                           exclude_fields: proc { |_type, _model| %i[] },
                           extra_fields: proc { |_type, _model| { priority: :string } }

  def exclude_gr_fields(_type)
    %i[id created_at updated_at gr_id parent_id area_id global_registry_area_id]
  end

  def relationship_attributes_to_push(type)
    entity_attributes = super(type)
    entity_attributes[:priority] = 'High' if type == :area
    entity_attributes
  end
end
