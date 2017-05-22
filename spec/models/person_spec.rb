# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Person' do
  describe ':create' do
    it 'should enqueue sidekiq job' do
      expect do
        create(:person)
      end.to change(GlobalRegistry::Bindings::Workers::PushGrEntityWorker.jobs, :size).by(1)
    end
  end

  describe ':push_entity_to_global_registry' do
    context 'create' do
      let(:person) { create(:person) }

      context '\'person\' entity_type does not exist' do
        around { |example| travel_to Time.utc(2001, 2, 3), &example }
        let!(:requests) do
          [stub_request(:get, 'https://backend.global-registry.org/entity_types')
            .with(query: { 'filters[name]' => 'person', 'filters[parent_id]' => nil })
            .to_return(body: file_fixture('get_entity_types.json'), status: 200),
           stub_request(:post, 'https://backend.global-registry.org/entity_types')
             .with(body: { entity_type: { name: 'person', parent_id: nil, field_type: 'entity' } })
             .to_return(body: file_fixture('post_entity_types_person.json'), status: 200),
           stub_request(:post, 'https://backend.global-registry.org/entity_types')
             .with(body: { entity_type: { name: 'first_name', parent_id: 'ee13a693-3ce7-4c19-b59a-30c8f137acd8',
                                          field_type: 'string' } })
             .to_return(status: 200),
           stub_request(:post, 'https://backend.global-registry.org/entity_types')
             .with(body: { entity_type: { name: 'last_name', parent_id: 'ee13a693-3ce7-4c19-b59a-30c8f137acd8',
                                          field_type: 'string' } })
             .to_return(status: 200),
           stub_request(:post, 'https://backend.global-registry.org/entities')
             .with(body: { entity: { person: { first_name: 'Tony', last_name: 'Stark',
                                               client_integration_id: person.id,
                                               client_updated_at: '2001-02-03 00:00:00',
                                               authentication: {
                                                 key_guid: '98711710-acb5-4a41-ba51-e0fc56644b53'
                                               } } } })
             .to_return(body: file_fixture('post_entities_person.json'), status: 200)]
        end

        it 'should create \'person\' entity_type and push entity' do
          person.push_entity_to_global_registry
          requests.each { |r| expect(r).to have_been_requested.once }
          expect(person.global_registry_id).to eq '22527d88-3cba-11e7-b876-129bd0521531'
        end
      end

      context '\'person\' entity_type exists' do
        around { |example| travel_to Time.utc(2001, 2, 3), &example }
        let!(:requests) do
          [stub_request(:get, 'https://backend.global-registry.org/entity_types')
            .with(query: { 'filters[name]' => 'person', 'filters[parent_id]' => nil })
            .to_return(body: file_fixture('get_entity_types_person.json'), status: 200),
           stub_request(:post, 'https://backend.global-registry.org/entities')
             .with(body: { entity: { person: { first_name: 'Tony', last_name: 'Stark',
                                               client_integration_id: person.id,
                                               client_updated_at: '2001-02-03 00:00:00',
                                               authentication: {
                                                 key_guid: '98711710-acb5-4a41-ba51-e0fc56644b53'
                                               } } } })
             .to_return(body: file_fixture('post_entities_person.json'), status: 200)]
        end

        it 'should skip creating entity_type and push the entity' do
          person.push_entity_to_global_registry
          requests.each { |r| expect(r).to have_been_requested.once }
          expect(person.global_registry_id).to eq '22527d88-3cba-11e7-b876-129bd0521531'
        end
      end

      context 'partial \'person\' entity_type exists' do
        around { |example| travel_to Time.utc(2001, 2, 3), &example }
        let!(:requests) do
          [stub_request(:get, 'https://backend.global-registry.org/entity_types')
            .with(query: { 'filters[name]' => 'person', 'filters[parent_id]' => nil })
            .to_return(body: file_fixture('get_entity_types_person_partial.json'), status: 200),
           stub_request(:post, 'https://backend.global-registry.org/entity_types')
             .with(body: { entity_type: { name: 'first_name', parent_id: 'ee13a693-3ce7-4c19-b59a-30c8f137acd8',
                                          field_type: 'string' } })
             .to_return(status: 200),
           stub_request(:post, 'https://backend.global-registry.org/entities')
             .with(body: { entity: { person: { first_name: 'Tony', last_name: 'Stark',
                                               client_integration_id: person.id,
                                               client_updated_at: '2001-02-03 00:00:00',
                                               authentication: {
                                                 key_guid: '98711710-acb5-4a41-ba51-e0fc56644b53'
                                               } } } })
             .to_return(body: file_fixture('post_entities_person.json'), status: 200)]
        end

        it 'should skip creating entity_type and push the entity' do
          person.push_entity_to_global_registry
          requests.each { |r| expect(r).to have_been_requested.once }
          expect(person.global_registry_id).to eq '22527d88-3cba-11e7-b876-129bd0521531'
        end
      end

      context '\'person\' entity_type is cached' do
        around { |example| travel_to Time.utc(2001, 2, 3), &example }
        before :each do
          person_entity_types = JSON.parse(file_fixture('get_entity_types_person.json').read)
          Rails.cache.write('GlobalRegistry::Bindings::EntityType::person', person_entity_types['entity_types'].first)
        end

        it 'should skip creating entity_type and push the entity' do
          request = stub_request(:post, 'https://backend.global-registry.org/entities')
                    .with(body: { entity: { person: { first_name: 'Tony', last_name: 'Stark',
                                                      client_integration_id: person.id,
                                                      client_updated_at: '2001-02-03 00:00:00',
                                                      authentication: {
                                                        key_guid: '98711710-acb5-4a41-ba51-e0fc56644b53'
                                                      } } } })
                    .to_return(body: file_fixture('post_entities_person.json'), status: 200)
          person.push_entity_to_global_registry
          expect(request).to have_been_requested.once
          expect(person.global_registry_id).to eq '22527d88-3cba-11e7-b876-129bd0521531'
        end
      end
    end

    context 'update' do
      let(:person) { create(:person, global_registry_id: 'f8d20318-2ff2-4a98-a5eb-e9d840508bf1') }
      context '\'person\' entity_type is cached' do
        around { |example| travel_to Time.utc(2001, 2, 3), &example }
        before :each do
          person_entity_types = JSON.parse(file_fixture('get_entity_types_person.json').read)
          Rails.cache.write('GlobalRegistry::Bindings::EntityType::person', person_entity_types['entity_types'].first)
        end

        it 'should skip creating entity_type and update the entity' do
          request = stub_request(:put,
                                 'https://backend.global-registry.org/entities/f8d20318-2ff2-4a98-a5eb-e9d840508bf1')
                    .with(body: { entity: { person: { first_name: 'Tony', last_name: 'Stark',
                                                      client_integration_id: person.id,
                                                      client_updated_at: '2001-02-03 00:00:00',
                                                      authentication: {
                                                        key_guid: '98711710-acb5-4a41-ba51-e0fc56644b53'
                                                      } } } })
                    .to_return(body: file_fixture('post_entities_person.json'), status: 200)
          person.push_entity_to_global_registry
          expect(request).to have_been_requested.once
        end

        context 'invalid entity id' do
          let!(:requests) do
            [stub_request(:put,
                          'https://backend.global-registry.org/entities/f8d20318-2ff2-4a98-a5eb-e9d840508bf1')
              .with(body: { entity: { person: { first_name: 'Tony', last_name: 'Stark',
                                                client_integration_id: person.id,
                                                client_updated_at: '2001-02-03 00:00:00',
                                                authentication: {
                                                  key_guid: '98711710-acb5-4a41-ba51-e0fc56644b53'
                                                } } } })
              .to_return(status: 404),
             stub_request(:post, 'https://backend.global-registry.org/entities')
               .with(body: { entity: { person: { first_name: 'Tony', last_name: 'Stark',
                                                 client_integration_id: person.id,
                                                 client_updated_at: '2001-02-03 00:00:00',
                                                 authentication: {
                                                   key_guid: '98711710-acb5-4a41-ba51-e0fc56644b53'
                                                 } } } })
               .to_return(body: file_fixture('post_entities_person.json'), status: 200)]
          end

          it 'should push entity as create' do
            person.push_entity_to_global_registry
            requests.each { |r| expect(r).to have_been_requested.once }
            expect(person.global_registry_id).to eq '22527d88-3cba-11e7-b876-129bd0521531'
          end
        end
      end
    end
  end
end
