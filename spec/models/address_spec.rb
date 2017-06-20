# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Address' do
  describe ':push_entity_to_global_registry_async' do
    it 'should enqueue sidekiq job' do
      address = build(:address)
      expect do
        address.push_entity_to_global_registry_async
      end.to change(GlobalRegistry::Bindings::Workers::PushGrEntityWorker.jobs, :size).by(1)
    end
  end

  describe ':delete_entity_from_global_registry_async' do
    it 'should enqueue sidekiq job' do
      address = build(:address, global_registry_id: '22527d88-3cba-11e7-b876-129bd0521531')
      expect do
        address.delete_entity_from_global_registry_async
      end.to change(GlobalRegistry::Bindings::Workers::DeleteGrEntityWorker.jobs, :size).by(1)
    end

    it 'should not enqueue sidekiq job when missing global_registry_id' do
      address = build(:address)
      expect do
        address.delete_entity_from_global_registry_async
      end.not_to change(GlobalRegistry::Bindings::Workers::DeleteGrEntityWorker.jobs, :size)
    end
  end

  describe ':push_entity_to_global_registry' do
    around { |example| travel_to Time.utc(2001, 2, 3), &example }
    context 'create' do
      context '\'address\' record does not belong to a person' do
        let(:address) { create(:address) }

        it 'should not create \'address\' entity_type and skip push of entity' do
          address.push_entity_to_global_registry
        end
      end

      context '\'address\' entity_type does not exist' do
        let!(:requests) do
          [stub_request(:get, 'https://backend.global-registry.org/entity_types')
            .with(query: { 'filters[name]' => 'person', 'filters[parent_id]' => nil })
            .to_return(body: file_fixture('get_entity_types_person.json'), status: 200),
           stub_request(:get, 'https://backend.global-registry.org/entity_types')
             .with(query: { 'filters[name]' => 'address',
                            'filters[parent_id]' => 'ee13a693-3ce7-4c19-b59a-30c8f137acd8' })
             .to_return(body: file_fixture('get_entity_types.json'), status: 200),
           stub_request(:post, 'https://backend.global-registry.org/entity_types')
             .with(body: { entity_type: { name: 'address', parent_id: 'ee13a693-3ce7-4c19-b59a-30c8f137acd8',
                                          field_type: 'entity' } })
             .to_return(body: file_fixture('post_entity_types_address.json'), status: 200),
           stub_request(:post, 'https://backend.global-registry.org/entity_types')
             .with(body: { entity_type: { name: 'zip', parent_id: 'f5331684-3ca8-11e7-b937-129bd0521531',
                                          field_type: 'string' } })
             .to_return(status: 200),
           stub_request(:post, 'https://backend.global-registry.org/entity_types')
             .with(body: { entity_type: { name: 'line1', parent_id: 'f5331684-3ca8-11e7-b937-129bd0521531',
                                          field_type: 'string' } })
             .to_return(status: 200),
           stub_request(:post, 'https://backend.global-registry.org/entity_types')
             .with(body: { entity_type: { name: 'line2', parent_id: 'f5331684-3ca8-11e7-b937-129bd0521531',
                                          field_type: 'string' } })
             .to_return(status: 200),
           stub_request(:post, 'https://backend.global-registry.org/entity_types')
             .with(body: { entity_type: { name: 'primary', parent_id: 'f5331684-3ca8-11e7-b937-129bd0521531',
                                          field_type: 'boolean' } })
             .to_return(status: 200),
           stub_request(:post, 'https://backend.global-registry.org/entity_types')
             .with(body: { entity_type: { name: 'postal_code', parent_id: 'f5331684-3ca8-11e7-b937-129bd0521531',
                                          field_type: 'string' } })
             .to_return(status: 200)]
        end

        context '\'address\' record belongs to a person without global registry id' do
          let(:person) { create(:person) }
          let(:address) { create(:address, person: person) }
          let!(:sub_requests) do
            [stub_request(:post, 'https://backend.global-registry.org/entities')
              .with(body: { entity: { person: { first_name: 'Tony', last_name: 'Stark',
                                                client_integration_id: person.id,
                                                client_updated_at: '2001-02-03 00:00:00',
                                                authentication: {
                                                  key_guid: '98711710-acb5-4a41-ba51-e0fc56644b53'
                                                } } } })
              .to_return(body: file_fixture('post_entities_person.json'), status: 200),
             stub_request(:put,
                          'https://backend.global-registry.org/entities/22527d88-3cba-11e7-b876-129bd0521531')
               .with(body: { entity: { person: { client_integration_id: person.id,
                                                 address: {
                                                   zip: '90265', primary: 'true',
                                                   line1: '10880 Malibu Point', postal_code: '90265',
                                                   client_integration_id: address.id,
                                                   client_updated_at: '2001-02-03 00:00:00'
                                                 } } } })
               .to_return(body: file_fixture('put_entities_address.json'), status: 200)]
          end

          it 'should create \'address\' entity_type and push person and address entities' do
            address.push_entity_to_global_registry
            (requests + sub_requests).each { |r| expect(r).to have_been_requested.once }
            expect(person.global_registry_id).to eq '22527d88-3cba-11e7-b876-129bd0521531'
            expect(address.global_registry_id).to eq '0a594356-3f1c-11e7-bba6-129bd0521531'
          end
        end

        context '\'address\' record belongs to an existing person entity' do
          let(:person) { create(:person, global_registry_id: '22527d88-3cba-11e7-b876-129bd0521531') }
          let(:address) { create(:address, person: person) }
          let!(:sub_requests) do
            [stub_request(:put,
                          'https://backend.global-registry.org/entities/22527d88-3cba-11e7-b876-129bd0521531')
              .with(body: { entity: { person: { client_integration_id: person.id,
                                                address: {
                                                  zip: '90265', primary: 'true',
                                                  line1: '10880 Malibu Point', postal_code: '90265',
                                                  client_integration_id: address.id,
                                                  client_updated_at: '2001-02-03 00:00:00'
                                                } } } })
              .to_return(body: file_fixture('put_entities_address.json'), status: 200)]
          end

          it 'should create \'address\' entity_type and push address entity' do
            address.push_entity_to_global_registry
            (requests + sub_requests).each { |r| expect(r).to have_been_requested.once }
            expect(address.global_registry_id).to eq '0a594356-3f1c-11e7-bba6-129bd0521531'
          end
        end
      end

      context '\'address\' and \'person\' entity_types exist' do
        let(:person) { create(:person, global_registry_id: '22527d88-3cba-11e7-b876-129bd0521531') }
        let(:address) { create(:address, person: person) }
        let!(:requests) do
          [stub_request(:get, 'https://backend.global-registry.org/entity_types')
            .with(query: { 'filters[name]' => 'person', 'filters[parent_id]' => nil })
            .to_return(body: file_fixture('get_entity_types_person.json'), status: 200),
           stub_request(:put,
                        'https://backend.global-registry.org/entities/22527d88-3cba-11e7-b876-129bd0521531')
             .with(body: { entity: { person: { client_integration_id: person.id,
                                               address: {
                                                 zip: '90265', primary: 'true',
                                                 line1: '10880 Malibu Point', postal_code: '90265',
                                                 client_integration_id: address.id,
                                                 client_updated_at: '2001-02-03 00:00:00'
                                               } } } })
             .to_return(body: file_fixture('put_entities_address.json'), status: 200)]
        end

        context '\'address\' entity_type has partial fields' do
          let!(:sub_requests) do
            [stub_request(:get, 'https://backend.global-registry.org/entity_types')
              .with(query: { 'filters[name]' => 'address',
                             'filters[parent_id]' => 'ee13a693-3ce7-4c19-b59a-30c8f137acd8' })
              .to_return(body: file_fixture('get_entity_types_address_partial.json'), status: 200),
             stub_request(:post, 'https://backend.global-registry.org/entity_types')
               .with(body: { entity_type: { name: 'line2', parent_id: 'f5331684-3ca8-11e7-b937-129bd0521531',
                                            field_type: 'string' } })
               .to_return(status: 200),
             stub_request(:post, 'https://backend.global-registry.org/entity_types')
               .with(body: { entity_type: { name: 'primary', parent_id: 'f5331684-3ca8-11e7-b937-129bd0521531',
                                            field_type: 'boolean' } })
               .to_return(status: 200)]
          end

          it 'should add missing fields and push address entity' do
            address.push_entity_to_global_registry
            (requests + sub_requests).each { |r| expect(r).to have_been_requested.once }
            expect(address.global_registry_id).to eq '0a594356-3f1c-11e7-bba6-129bd0521531'
          end
        end

        context '\'address\' entity_type has all fields' do
          let!(:sub_requests) do
            [stub_request(:get, 'https://backend.global-registry.org/entity_types')
              .with(query: { 'filters[name]' => 'address',
                             'filters[parent_id]' => 'ee13a693-3ce7-4c19-b59a-30c8f137acd8' })
              .to_return(body: file_fixture('get_entity_types_address.json'), status: 200)]
          end

          it 'should push address entity' do
            address.push_entity_to_global_registry
            (requests + sub_requests).each { |r| expect(r).to have_been_requested.once }
            expect(address.global_registry_id).to eq '0a594356-3f1c-11e7-bba6-129bd0521531'
          end
        end
      end

      context 'update' do
        before :each do
          person_entity_types = JSON.parse(file_fixture('get_entity_types_person.json').read)
          Rails.cache.write('GlobalRegistry::Bindings::EntityType::person', person_entity_types['entity_types'].first)
          address_entity_types = JSON.parse(file_fixture('get_entity_types_address.json').read)
          Rails.cache.write('GlobalRegistry::Bindings::EntityType::address',
                            address_entity_types['entity_types'].first)
        end
        let(:person) { create(:person, global_registry_id: '22527d88-3cba-11e7-b876-129bd0521531') }
        let(:address) do
          create(:address, person: person, global_registry_id: '0a594356-3f1c-11e7-bba6-129bd0521531')
        end
        let!(:request) do
          stub_request(:put,
                       'https://backend.global-registry.org/entities/22527d88-3cba-11e7-b876-129bd0521531')
            .with(body: { entity: { person: { client_integration_id: person.id,
                                              address: {
                                                zip: '90265', primary: 'false',
                                                line1: '100 Sesame Street', postal_code: '90265',
                                                client_integration_id: address.id,
                                                client_updated_at: '2001-02-03 00:00:00'
                                              } } } })
            .to_return(body: file_fixture('put_entities_address.json'), status: 200)
        end

        it 'should push address entity' do
          address.address1 = '100 Sesame Street'
          address.primary = false
          expect do
            address.push_entity_to_global_registry
          end.to_not(change { address.global_registry_id })
          expect(request).to have_been_requested.once
        end
      end
    end
  end
end
