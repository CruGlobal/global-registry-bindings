# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'GlobalRegistry::Bindings' do
  describe 'ActiveRecord::Base extensions' do
    it 'should respond to global_registry_bindings' do
      expect(::ActiveRecord::Base).to respond_to :global_registry_bindings
    end
  end

  describe 'Options' do
    it 'should have default values for all options' do
      expect(Default.global_registry_entity.id_column).to be :global_registry_id
      expect(Default.global_registry_entity.mdm_id_column).to be nil
      expect(Default.global_registry_entity.parent_association).to be nil
      expect(Default.global_registry_entity.push_on)
        .to contain_exactly(:create, :update, :destroy)
      expect(Default.global_registry_entity.mdm_timeout).to eq 1.minute
      expect(Default.global_registry_entity.type).to be :default
      expect(Default.global_registry_entity.exclude_fields)
        .to contain_exactly(:global_registry_id, :id, :created_at, :updated_at)
      expect(Default.global_registry_entity.extra_fields).to be_a(Hash).and be_empty
    end

    it 'should parse and set mdm options' do
      expect(Namespaced::Person.global_registry_entity.id_column).to be :global_registry_id
      expect(Namespaced::Person.global_registry_entity.mdm_id_column).to be :global_registry_mdm_id
      expect(Namespaced::Person.global_registry_entity.mdm_timeout).to eq 24.hours
      expect(Namespaced::Person.global_registry_entity.type).to be :person
      expect(Namespaced::Person.global_registry_entity.exclude_fields)
        .to contain_exactly(:country_of_residence_gr_id, :country_of_residence_id, :country_of_service_gr_id,
                            :country_of_service_id, :created_at, :global_registry_id, :global_registry_mdm_id,
                            :guid, :id, :updated_at)
      expect(Namespaced::Person.global_registry_entity.extra_fields).to be_a(Hash).and be_empty
      expect(GlobalRegistry::Bindings::Workers::PullNamespacedPersonMdmIdWorker.get_sidekiq_options)
        .to include('unique' => :until_timeout, 'unique_expiration' => 24.hours)
    end

    it 'should parse and set exclude and extra fields options' do
      address = build(:address)
      expect(Address.global_registry_entity.id_column).to be :global_registry_id
      expect(Address.global_registry_entity.mdm_id_column).to be nil
      expect(Address.global_registry_entity.type).to be :address
      expect(Address.global_registry_entity.parent_association).to be :person
      expect(Address.global_registry_entity.exclude_fields).to be_a Proc
      expect(address.global_registry_entity.exclude_fields)
        .to contain_exactly(:global_registry_id, :id, :created_at, :updated_at, :person_id, :address1)
      expect(Address.global_registry_entity.extra_fields).to be_a Symbol
      expect(address.global_registry_entity.extra_fields)
        .to include(line1: :string, postal_code: :string)
    end

    it 'should parse and set push_on fields' do
      org = build(:organization)
      expect(Organization.global_registry_entity.id_column).to be :gr_id
      expect(Organization.global_registry_entity.mdm_id_column).to be nil
      expect(Organization.global_registry_entity.type).to be_a Proc
      expect(org.global_registry_entity.type).to be :fancy_org
      expect(Organization.global_registry_entity.parent_association).to be :parent
      expect(Organization.global_registry_entity.push_on).to be_an(Array).and eq(%i[create destroy])
      expect(Organization.global_registry_entity.exclude_fields).to be_a Symbol
      expect(org.global_registry_entity.exclude_fields)
        .to contain_exactly(:gr_id, :id, :created_at, :updated_at, :parent_id, :area_id, :global_registry_area_id)
      expect(Organization.global_registry_entity.extra_fields).to be_a Proc
      expect(org.global_registry_entity.extra_fields).to be_a(Hash).and be_empty
    end

    it 'should parse and set relationship fields' do
      person = build(:person)
      org = build(:organization)
      assignment = build(:assignment, person: person, organization: org)
      expect(Assignment.global_registry_relationship(:fancy_org_assignment).id_column).to be :global_registry_id
      expect(Assignment.global_registry_relationship(:fancy_org_assignment).type).to be :fancy_org_assignment
      expect(Assignment.global_registry_relationship(:fancy_org_assignment).primary_association).to be :person
      expect(Assignment.global_registry_relationship(:fancy_org_assignment).related_association).to be :organization
      expect(assignment.global_registry_relationship(:fancy_org_assignment).primary_relationship_name).to be :person
      expect(assignment.global_registry_relationship(:fancy_org_assignment).related_relationship_name).to be :fancy_org
      expect(assignment.global_registry_relationship(:fancy_org_assignment).exclude_fields)
        .to contain_exactly(:global_registry_id, :id, :created_at, :updated_at, :person_id, :organization_id,
                            :assigned_by_gr_rel_id, :assigned_by_id)
      expect(assignment.global_registry_relationship(:fancy_org_assignment).extra_fields)
        .to be_a(Hash)
    end
  end
end
