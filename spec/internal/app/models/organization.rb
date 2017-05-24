# frozen_string_literal: true

class Organization < ActiveRecord::Base
  has_many :children, class_name: 'Organization', foreign_key: :parent_id
  belongs_to :parent, class_name: 'Organization'
  global_registry_bindings id_column: :gr_id,
                           type: :fancy_org,
                           push_on: %i[create delete],
                           parent_association: :parent
end
