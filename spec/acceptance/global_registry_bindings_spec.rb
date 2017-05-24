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
      expect(Default.global_registry_bindings_options[:id_column]).to be :global_registry_id
      expect(Default.global_registry_bindings_options[:mdm_id_column]).to be nil
      expect(Default.global_registry_bindings_options[:type]).to be :default
      expect(Default.global_registry_bindings_options[:exclude_fields])
        .to contain_exactly(:global_registry_id, :id, :created_at, :updated_at)
      expect(Default.global_registry_bindings_options[:extra_fields]).to be_a(Hash).and be_empty
    end

    it 'should parse and set mdm options' do
      expect(Person.global_registry_bindings_options[:id_column]).to be :global_registry_id
      expect(Person.global_registry_bindings_options[:mdm_id_column]).to be :global_registry_mdm_id
      expect(Person.global_registry_bindings_options[:type]).to be :person
      expect(Person.global_registry_bindings_options[:exclude_fields])
        .to contain_exactly(:global_registry_id, :id, :created_at, :updated_at, :global_registry_mdm_id, :guid)
      expect(Person.global_registry_bindings_options[:extra_fields]).to be_a(Hash).and be_empty
    end

    it 'should parse and set exclude and extra fields options' do
      expect(Address.global_registry_bindings_options[:id_column]).to be :global_registry_id
      expect(Address.global_registry_bindings_options[:mdm_id_column]).to be nil
      expect(Address.global_registry_bindings_options[:type]).to be :address
      expect(Address.global_registry_bindings_options[:parent_association]).to be :person
      expect(Address.global_registry_bindings_options[:exclude_fields])
        .to contain_exactly(:global_registry_id, :id, :created_at, :updated_at, :person_id, :address1)
      expect(Address.global_registry_bindings_options[:extra_fields])
        .to include(line1: :string, postal_code: :string)
    end

    it 'should parse and set push_on fields' do
      expect(Organization.global_registry_bindings_options[:id_column]).to be :gr_id
      expect(Organization.global_registry_bindings_options[:mdm_id_column]).to be nil
      expect(Organization.global_registry_bindings_options[:type]).to be :fancy_org
      expect(Organization.global_registry_bindings_options[:parent_association]).to be :parent
      expect(Organization.global_registry_bindings_options[:push_on]).to be_an(Array).and eq(%i[create delete])
      expect(Organization.global_registry_bindings_options[:exclude_fields])
        .to contain_exactly(:gr_id, :id, :created_at, :updated_at, :parent_id)
      expect(Organization.global_registry_bindings_options[:extra_fields]).to be_a(Hash).and be_empty
    end
  end
end
