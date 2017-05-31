# frozen_string_literal: true

ActiveRecord::Schema.define(version: 0) do
  # enable_extension 'uuid-ossp'

  create_table :people, force: true do |t|
    t.string :global_registry_id
    t.string :global_registry_mdm_id
    t.string :first_name
    t.string :last_name
    t.string :guid
    t.timestamps
  end

  create_table :addresses, force: true do |t|
    t.string :global_registry_id
    t.string :address1
    t.string :zip
    t.boolean :primary
    t.references :person, index: true
    t.timestamps
  end

  create_table :organizations, force: true do |t|
    t.string :gr_id
    t.string :name
    t.text :description
    t.date :start_date
    t.references :parent, index: true
    t.timestamps
  end

  create_table :assignments, force: true do |t|
    t.string :global_registry_id
    t.string :role
    t.datetime :hired_at
    t.references :person, index: true
    t.references :organization, index: true
    t.timestamps
  end
end
