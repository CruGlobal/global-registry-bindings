# frozen_string_literal: true

require 'securerandom'

FactoryGirl.define do
  factory :person, class: Namespaced::Person do
    first_name 'Tony'
    last_name 'Stark'
    guid '98711710-acb5-4a41-ba51-e0fc56644b53'
    global_registry_id nil
    global_registry_mdm_id nil
    country_of_service_id nil
    country_of_service_gr_id nil
    country_of_residence_id nil
    country_of_residence_gr_id nil
  end

  factory :user_edited, class: Namespaced::Person::UserEdited do
    first_name 'Bruce'
    last_name 'Banner'
    guid 'e4b665fe-df98-46b4-adb8-e878669dcdd4'
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
    area_id nil
    global_registry_area_id nil
  end

  factory :assignment do
    role 'leader'
    hired_at { 2.months.ago }
    person_id nil
    organization_id nil
    global_registry_id nil
  end

  factory :area do
    area_name 'Best Area'
    area_code 'BEST'
    is_active true
  end

  factory :country do
    global_registry_id nil
    name 'Sokovia'
  end

  factory :community do
    global_registry_id nil
    infobase_gr_id nil
    name 'Community'
    infobase_id 1
  end
end
