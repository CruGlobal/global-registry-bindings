# frozen_string_literal: true

require 'securerandom'

FactoryGirl.define do
  factory :person do
    first_name 'Tony'
    last_name 'Stark'
    guid '98711710-acb5-4a41-ba51-e0fc56644b53'
    global_registry_id nil
    global_registry_mdm_id nil
  end

  factory :address do
    address1 '10880 Malibu Point'
    zip '90265'
    primary true
    global_registry_id nil
    person_id nil
  end

  factory :organization do
    name 'Organization'
    description 'Fancy Organization'
    start_date { Time.zone.today }
    parent_id nil
    gr_id nil
  end
end
