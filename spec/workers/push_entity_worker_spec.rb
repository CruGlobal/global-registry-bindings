# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GlobalRegistry::Bindings::Workers::PushEntityWorker do
  around { |example| travel_to Time.utc(2001, 2, 3), &example }
  describe '#perform(model_class, id)' do
    context Namespaced::Person do
      let(:person) { create(:person) }
      context 'with valid id' do
        it 'should call #push_entity_to_global_registry' do
          expect(Namespaced::Person).to receive(:find).with(person.id).and_return(person)

          worker = GlobalRegistry::Bindings::Workers::PushEntityWorker.new
          expect(worker).to receive(:push_entity_to_global_registry)
          worker.perform('Namespaced::Person', person.id)
          expect(worker.model).to be person
        end
      end

      context 'with invalid id' do
        it 'should fail silently' do
          expect(Namespaced::Person).to receive(:find).with(person.id).and_raise(ActiveRecord::RecordNotFound)
          expect(GlobalRegistry::Bindings::Workers::PushEntityWorker).not_to receive(:push_entity_to_global_registry)

          worker = GlobalRegistry::Bindings::Workers::PushEntityWorker.new
          worker.perform(Namespaced::Person, person.id)
          expect(worker.model).to be nil
        end
      end
    end
  end

  describe '#push_entity_to_global_registry' do
    describe Organization do
      let(:worker) { GlobalRegistry::Bindings::Workers::PushEntityWorker.new organization }
      context 'and unknown \'fancy_org\' entity_type' do
        let!(:requests) do
          [stub_request(:get, 'https://backend.global-registry.org/entity_types')
            .with(query: { 'filters[name]' => 'fancy_org', 'filters[parent_id]' => nil })
            .to_return(body: file_fixture('get_entity_types.json'), status: 200),
           stub_request(:post, 'https://backend.global-registry.org/entity_types')
             .with(body: { entity_type: { name: 'fancy_org', parent_id: nil, field_type: 'entity' } })
             .to_return(body: file_fixture('post_entity_types_fancy_org.json'), status: 200),
           stub_request(:post, 'https://backend.global-registry.org/entity_types')
             .with(body: { entity_type: { name: 'name', parent_id: '025a1128-3f33-11e7-b876-129bd0521531',
                                          field_type: 'string' } })
             .to_return(status: 200),
           stub_request(:post, 'https://backend.global-registry.org/entity_types')
             .with(body: { entity_type: { name: 'description', parent_id: '025a1128-3f33-11e7-b876-129bd0521531',
                                          field_type: 'string' } })
             .to_return(status: 200),
           stub_request(:post, 'https://backend.global-registry.org/entity_types')
             .with(body: { entity_type: { name: 'start_date', parent_id: '025a1128-3f33-11e7-b876-129bd0521531',
                                          field_type: 'date' } })
             .to_return(status: 200)]
        end

        context 'with root level organization' do
          let(:organization) { create(:organization) }
          let!(:sub_requests) do
            [stub_request(:post, 'https://backend.global-registry.org/entities')
              .with(body: { entity: { fancy_org: { name: 'Organization', description: 'Fancy Organization',
                                                   start_date: '2001-02-03', parent_id: nil,
                                                   client_integration_id: organization.id,
                                                   client_updated_at: '2001-02-03 00:00:00' } } })
              .to_return(body: file_fixture('post_entities_fancy_org.json'), status: 200)]
          end

          it 'should create \'fancy_org\' entity_type and push entity to Global Registry' do
            worker.push_entity_to_global_registry
            (requests + sub_requests).each { |r| expect(r).to have_been_requested.once }
            expect(organization.gr_id).to eq 'aebb4170-3f34-11e7-bba6-129bd0521531'
          end
        end

        context 'with organization with parent missing global_registry_id' do
          let(:parent) { create(:organization, name: 'Parent', description: 'Parent Fancy Organization') }
          let(:organization) { create(:organization, parent: parent) }

          it 'should create \'fancy_org\' entity_type raise an exception' do
            expect do
              worker.push_entity_to_global_registry
              requests.each { |r| expect(r).to have_been_requested.once }
            end.to raise_error GlobalRegistry::Bindings::ParentEntityMissingGlobalRegistryId,
                               "Organization(#{organization.id}) has parent entity Organization(#{parent.id}) " \
                               'missing global_registry_id; will retry.'
          end
        end

        context 'organization with an existing parent' do
          let(:parent) do
            create :organization, name: 'Parent', description: 'Parent Fancy Organization',
                                  gr_id: 'cd5da38a-c336-46a7-b818-dcdd51c4acde'
          end
          let(:organization) { create(:organization, parent: parent) }
          let!(:sub_requests) do
            [stub_request(:post, 'https://backend.global-registry.org/entities')
              .with(body: { entity: { fancy_org: { name: 'Organization', description: 'Fancy Organization',
                                                   start_date: '2001-02-03',
                                                   parent_id: 'cd5da38a-c336-46a7-b818-dcdd51c4acde',
                                                   client_integration_id: organization.id,
                                                   client_updated_at: '2001-02-03 00:00:00' } } })
              .to_return(body: file_fixture('post_entities_fancy_org.json'), status: 200)]
          end

          it 'should create \'fancy_org\' entity_type and push both entities' do
            worker.push_entity_to_global_registry
            (requests + sub_requests).each { |r| expect(r).to have_been_requested.once }
            expect(parent.gr_id).to eq 'cd5da38a-c336-46a7-b818-dcdd51c4acde'
            expect(organization.gr_id).to eq 'aebb4170-3f34-11e7-bba6-129bd0521531'
          end
        end
      end
    end

    describe Namespaced::Person do
      let(:worker) { GlobalRegistry::Bindings::Workers::PushEntityWorker.new person }
      context 'as create' do
        let(:person) { create(:person) }

        context '\'person\' entity_type does not exist' do
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
            worker.push_entity_to_global_registry
            requests.each { |r| expect(r).to have_been_requested.once }
            expect(person.global_registry_id).to eq '22527d88-3cba-11e7-b876-129bd0521531'
          end
        end

        context '\'person\' entity_type exists' do
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
            worker.push_entity_to_global_registry
            requests.each { |r| expect(r).to have_been_requested.once }
            expect(person.global_registry_id).to eq '22527d88-3cba-11e7-b876-129bd0521531'
          end
        end

        context 'partial \'person\' entity_type exists' do
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
            worker.push_entity_to_global_registry
            requests.each { |r| expect(r).to have_been_requested.once }
            expect(person.global_registry_id).to eq '22527d88-3cba-11e7-b876-129bd0521531'
          end
        end

        context '\'person\' entity_type is cached' do
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
            worker.push_entity_to_global_registry
            expect(request).to have_been_requested.once
            expect(person.global_registry_id).to eq '22527d88-3cba-11e7-b876-129bd0521531'
          end
        end
      end

      context 'as an update' do
        let(:person) { create(:person, global_registry_id: 'f8d20318-2ff2-4a98-a5eb-e9d840508bf1') }
        context '\'person\' entity_type is cached' do
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
            worker.push_entity_to_global_registry
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
              worker.push_entity_to_global_registry
              requests.each { |r| expect(r).to have_been_requested.once }
              expect(person.global_registry_id).to eq '22527d88-3cba-11e7-b876-129bd0521531'
            end
          end
        end
      end
    end

    describe Address do
      let(:worker) { GlobalRegistry::Bindings::Workers::PushEntityWorker.new address }
      context 'as create' do
        context '\'address\' record does not belong to a person' do
          let(:address) { create(:address) }

          it 'should not create \'address\' entity_type and skip push of entity' do
            worker.push_entity_to_global_registry
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

            it 'should create \'address\' entity_type and raise an error' do
              expect do
                worker.push_entity_to_global_registry
              end.to raise_error GlobalRegistry::Bindings::ParentEntityMissingGlobalRegistryId,
                                 "Address(#{address.id}) has parent entity Namespaced::Person(#{person.id}) " \
                                 'missing global_registry_id; will retry.'
              requests.each { |r| expect(r).to have_been_requested.once }
              expect(person.global_registry_id).to be nil
              expect(address.global_registry_id).to be nil
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
              worker.push_entity_to_global_registry
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
              worker.push_entity_to_global_registry
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
              worker.push_entity_to_global_registry
              (requests + sub_requests).each { |r| expect(r).to have_been_requested.once }
              expect(address.global_registry_id).to eq '0a594356-3f1c-11e7-bba6-129bd0521531'
            end
          end
        end
      end

      context 'as an update' do
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
            worker.push_entity_to_global_registry
          end.to_not(change { address.global_registry_id })
          expect(request).to have_been_requested.once
        end
      end
    end

    describe Community do
      let(:worker) { GlobalRegistry::Bindings::Workers::PushEntityWorker.new community }
      let(:community) { create(:community, infobase_id: 234) }
      let!(:request) do
        stub_request(:post, 'https://backend.global-registry.org/entities')
          .with(body: { entity: { community: { name: 'Community', client_integration_id: community.id,
                                               client_updated_at: '2001-02-03 00:00:00' } } })
          .to_return(body: file_fixture('post_entities_community.json'), status: 200)
      end

      it 'should push community entity' do
        worker.push_entity_to_global_registry
        expect(request).to have_been_requested.once
        expect(community.global_registry_id).to eq '6133f6fe-c63a-425a-bb46-68917c689723'
      end
    end
  end
end
