# frozen_string_literal: true

FactoryGirl.define do
  factory :person do
    first_name 'Tony'
    last_name 'Stark'
    global_registry_id nil
    global_registry_mdm_id nil
  end
end
