# frozen_string_literal: true

ActiveRecord::Schema.define(version: 0) do
  # enable_extension 'uuid-ossp'

  create_table :people, force: true do |t|
    t.string :global_registry_id
    t.string :global_registry_mdm_id
    t.string :first_name
    t.string :last_name
    t.string :guid
    t.references :country_of_service, index: true
    t.references :country_of_residence, index: true
    t.string :country_of_service_gr_id
    t.string :country_of_residence_gr_id
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
    t.references :area, index: true
    t.string :global_registry_area_id
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

  create_table :areas, force: true do |t|
    t.string :global_registry_id
    t.string :area_name
    t.string :area_code
    t.boolean :is_active
    t.timestamps
  end

  create_table :countries, force: true do |t|
    t.string :name
    t.string :global_registry_id
    t.timestamps
  end

  create_table :communities, force: true do |t|
    t.string :name
    t.string :global_registry_id
    t.integer :infobase_id
    t.string :infobase_gr_id
    t.timestamps
  end
end
