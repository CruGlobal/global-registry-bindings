# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Assignment' do
  describe ':push_relationship_to_global_registry_async' do
    it 'should enqueue sidekiq job' do
      assignment = build(:assignment)
      expect do
        assignment.push_relationship_to_global_registry_async
      end.to change(GlobalRegistry::Bindings::Workers::PushRelationshipWorker.jobs, :size).by(1)
    end
  end

  describe ':push_relationship_to_global_registry' do
    context '#create' do
      let(:person) { create(:person, global_registry_id: '22527d88-3cba-11e7-b876-129bd0521531') }
      let(:organization) { create(:organization, gr_id: 'aebb4170-3f34-11e7-bba6-129bd0521531') }
      let(:assignment) { create(:assignment, person: person, organization: organization) }
      let!(:requests) do
        [stub_request(:get, 'https://backend.global-registry.org/entity_types')
          .with(query: { 'filters[name]' => 'person', 'filters[parent_id]' => nil })
          .to_return(body: file_fixture('get_entity_types_person.json'), status: 200),
         stub_request(:get, 'https://backend.global-registry.org/entity_types')
           .with(query: { 'filters[name]' => 'fancy_org', 'filters[parent_id]' => nil })
           .to_return(body: file_fixture('get_entity_types_fancy_org.json'), status: 200),
         stub_request(:put, "https://backend.global-registry.org/entities/#{person.global_registry_id}")
           .with(body: { entity: { person: { 'fancy_org:relationship': {
                   role: 'leader', hired_at: '2000-12-03 00:00:00',
                   client_integration_id: assignment.id,
                   client_updated_at: '2001-02-03 00:00:00', fancy_org: organization.gr_id
                 } }, client_integration_id: person.id } }, query: { full_response: 'true',
                                                                     fields: 'fancy_org:relationship' })
           .to_return(body: file_fixture('put_entities_person_relationship.json'), status: 200),
         stub_request(:put, 'https://backend.global-registry.org/entities/51a014a4-4252-11e7-944f-129bd0521531')
           .with(body: { entity: { role: 'leader', hired_at: '2000-12-03 00:00:00',
                                   client_integration_id: assignment.id,
                                   client_updated_at: '2001-02-03 00:00:00' } })
           .to_return(body: file_fixture('put_entities_relationship.json'), status: 200)]
      end

      context '\'assignment\' relationship_type does not exist' do
        around { |example| travel_to Time.utc(2001, 2, 3), &example }
        let!(:sub_requests) do
          [stub_request(:get, 'https://backend.global-registry.org/relationship_types')
            .with(query: { 'filters[between]' =>
                              'ee13a693-3ce7-4c19-b59a-30c8f137acd8,025a1128-3f33-11e7-b876-129bd0521531' })
            .to_return(body: file_fixture('get_relationship_types.json'), status: 200),
           stub_request(:post, 'https://backend.global-registry.org/relationship_types')
             .with(body: { relationship_type: { entity_type1_id: 'ee13a693-3ce7-4c19-b59a-30c8f137acd8',
                                                entity_type2_id: '025a1128-3f33-11e7-b876-129bd0521531',
                                                relationship1: 'person', relationship2: 'fancy_org' } })
             .to_return(body: file_fixture('post_relationship_types_person_fancy_org.json'), status: 200),
           stub_request(:put,
                        'https://backend.global-registry.org/relationship_types/5d721db8-4248-11e7-90b4-129bd0521531')
             .with(body: { relationship_type: { fields: [{ name: 'role', field_type: 'string' },
                                                         { name: 'hired_at', field_type: 'datetime' }] } })
             .to_return(body: file_fixture('put_relationship_types_fields.json'), status: 200)]
        end

        it 'should create \'assignment\' relationship_type and push relationship' do
          assignment.push_relationship_to_global_registry
          (requests + sub_requests).each { |r| expect(r).to have_been_requested.once }
          expect(assignment.global_registry_id).to eq '51a014a4-4252-11e7-944f-129bd0521531'
        end
      end

      context '\'assignment\' relationship_type partially exists' do
        around { |example| travel_to Time.utc(2001, 2, 3), &example }
        let!(:sub_requests) do
          [stub_request(:get, 'https://backend.global-registry.org/relationship_types')
            .with(query: { 'filters[between]' =>
                              'ee13a693-3ce7-4c19-b59a-30c8f137acd8,025a1128-3f33-11e7-b876-129bd0521531' })
            .to_return(body: file_fixture('get_relationship_types_person_fancy_org_partial.json'), status: 200),
           stub_request(:put,
                        'https://backend.global-registry.org/relationship_types/5d721db8-4248-11e7-90b4-129bd0521531')
             .with(body: { relationship_type: { fields: [{ name: 'role', field_type: 'string' }] } })
             .to_return(body: file_fixture('put_relationship_types_fields.json'), status: 200)]
        end

        it 'should add fields to relationship type and push relationship' do
          assignment.push_relationship_to_global_registry
          (requests + sub_requests).each { |r| expect(r).to have_been_requested.once }
          expect(assignment.global_registry_id).to eq '51a014a4-4252-11e7-944f-129bd0521531'
        end
      end

      context '\'assignment\' relationship_type exists' do
        around { |example| travel_to Time.utc(2001, 2, 3), &example }
        let!(:sub_requests) do
          [stub_request(:get, 'https://backend.global-registry.org/relationship_types')
            .with(query: { 'filters[between]' =>
                              'ee13a693-3ce7-4c19-b59a-30c8f137acd8,025a1128-3f33-11e7-b876-129bd0521531' })
            .to_return(body: file_fixture('get_relationship_types_person_fancy_org.json'), status: 200)]
        end

        it 'should add fields to relationship type and push relationship' do
          assignment.push_relationship_to_global_registry
          (requests + sub_requests).each { |r| expect(r).to have_been_requested.once }
          expect(assignment.global_registry_id).to eq '51a014a4-4252-11e7-944f-129bd0521531'
        end
      end
    end

    context '#update' do
      let(:person) { create(:person, global_registry_id: '22527d88-3cba-11e7-b876-129bd0521531') }
      let(:organization) { create(:organization, gr_id: 'aebb4170-3f34-11e7-bba6-129bd0521531') }
      let(:assignment) do
        create(:assignment, person: person, organization: organization,
                            global_registry_id: '51a014a4-4252-11e7-944f-129bd0521531')
      end

      context '\'assignment\' relationship_type is cached' do
        around { |example| travel_to Time.utc(2001, 2, 3), &example }
        before :each do
          person_entity_types = JSON.parse(file_fixture('get_entity_types_person.json').read)
          organization_entity_types = JSON.parse(file_fixture('get_entity_types_fancy_org.json').read)
          assignment_relationship_type = JSON.parse(file_fixture('get_relationship_types_person_fancy_org.json').read)
          Rails.cache.write('GlobalRegistry::Bindings::EntityType::person', person_entity_types['entity_types'].first)
          Rails.cache.write('GlobalRegistry::Bindings::EntityType::fancy_org',
                            organization_entity_types['entity_types'].first)
          Rails.cache.write('GlobalRegistry::Bindings::RelationshipType::person::fancy_org::person',
                            assignment_relationship_type['relationship_types'].first)
        end

        it 'should push relationship' do
          request = stub_request(:put,
                                 'https://backend.global-registry.org/entities/51a014a4-4252-11e7-944f-129bd0521531')
                    .with(body: { entity: { role: 'leader', hired_at: '2000-12-03 00:00:00',
                                            client_integration_id: assignment.id,
                                            client_updated_at: '2001-02-03 00:00:00' } })
                    .to_return(body: file_fixture('put_entities_relationship.json'), status: 200)

          assignment.push_relationship_to_global_registry
          expect(request).to have_been_requested.once
          expect(assignment.global_registry_id).to eq '51a014a4-4252-11e7-944f-129bd0521531'
        end
      end
    end
  end
end
