# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GlobalRegistry::Bindings::Workers::PushRelationshipWorker do
  around { |example| travel_to Time.utc(2001, 2, 3), &example }
  describe '#perform(model_class, id, type)' do
    context Assignment do
      let(:assignment) { create(:assignment) }
      context 'with valid id' do
        it 'should call #push_relationship_to_global_registry' do
          expect(Assignment).to receive(:find).with(assignment.id).and_return(assignment)

          worker = GlobalRegistry::Bindings::Workers::PushRelationshipWorker.new
          expect(worker).to receive(:push_relationship_to_global_registry)
          worker.perform('Assignment', assignment.id, :assignment)
          expect(worker.model).to be assignment
        end
      end

      context 'with invalid id' do
        it 'should fail silently' do
          expect(Assignment).to receive(:find).with(assignment.id).and_raise(ActiveRecord::RecordNotFound)
          expect(GlobalRegistry::Bindings::Workers::PushRelationshipWorker)
            .not_to receive(:push_relationship_to_global_registry)

          worker = GlobalRegistry::Bindings::Workers::PushRelationshipWorker.new
          worker.perform(Assignment, assignment.id, :assignment)
          expect(worker.model).to be nil
        end
      end
    end
  end

  describe '#push_relationship_to_global_registry' do
    describe Assignment do
      let(:worker) { GlobalRegistry::Bindings::Workers::PushRelationshipWorker.new assignment, :assignment }
      context 'as create' do
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
             .to_return(body: file_fixture('put_entities_person_relationship.json'), status: 200)]
        end

        context '\'assignment\' relationship_type does not exist' do
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
            worker.push_relationship_to_global_registry
            (requests + sub_requests).each { |r| expect(r).to have_been_requested.once }
            expect(assignment.global_registry_id).to eq '51a014a4-4252-11e7-944f-129bd0521531'
          end
        end

        context '\'assignment\' relationship_type partially exists' do
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
            worker.push_relationship_to_global_registry
            (requests + sub_requests).each { |r| expect(r).to have_been_requested.once }
            expect(assignment.global_registry_id).to eq '51a014a4-4252-11e7-944f-129bd0521531'
          end
        end

        context '\'assignment\' relationship_type exists' do
          let!(:sub_requests) do
            [stub_request(:get, 'https://backend.global-registry.org/relationship_types')
              .with(query: { 'filters[between]' =>
                                'ee13a693-3ce7-4c19-b59a-30c8f137acd8,025a1128-3f33-11e7-b876-129bd0521531' })
              .to_return(body: file_fixture('get_relationship_types_person_fancy_org.json'), status: 200)]
          end

          it 'should add fields to relationship type and push relationship' do
            worker.push_relationship_to_global_registry
            (requests + sub_requests).each { |r| expect(r).to have_been_requested.once }
            expect(assignment.global_registry_id).to eq '51a014a4-4252-11e7-944f-129bd0521531'
          end
        end
      end

      context 'as an update' do
        let(:person) { create(:person, global_registry_id: '22527d88-3cba-11e7-b876-129bd0521531') }
        let(:organization) { create(:organization, gr_id: 'aebb4170-3f34-11e7-bba6-129bd0521531') }
        let(:assignment) do
          create(:assignment, person: person, organization: organization,
                              global_registry_id: '51a014a4-4252-11e7-944f-129bd0521531')
        end

        context '\'assignment\' relationship_type is cached' do
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
            request = stub_request(:put, "https://backend.global-registry.org/entities/#{person.global_registry_id}")
                      .with(body: { entity: { person: { 'fancy_org:relationship': {
                              role: 'leader', hired_at: '2000-12-03 00:00:00',
                              client_integration_id: assignment.id,
                              client_updated_at: '2001-02-03 00:00:00', fancy_org: organization.gr_id
                            } }, client_integration_id: person.id } }, query: { full_response: 'true',
                                                                                fields: 'fancy_org:relationship' })
                      .to_return(body: file_fixture('put_entities_person_relationship.json'), status: 200,
                                 headers: { 'Content-Type' => 'application/json' })

            worker.push_relationship_to_global_registry
            expect(request).to have_been_requested.once
            expect(assignment.global_registry_id).to eq '51a014a4-4252-11e7-944f-129bd0521531'
          end

          context '\'fancy_org\' foreign key changed' do
            let!(:requests) do
              [stub_request(:put, "https://backend.global-registry.org/entities/#{person.global_registry_id}")
                .with(body: { entity: { person: { 'fancy_org:relationship': {
                        role: 'leader', hired_at: '2000-12-03 00:00:00',
                        client_integration_id: assignment.id,
                        client_updated_at: '2001-02-03 00:00:00', fancy_org: organization.gr_id
                      } }, client_integration_id: person.id } }, query: { full_response: 'true',
                                                                          fields: 'fancy_org:relationship' })
                .to_return(body: file_fixture('put_entities_relationship_400.json'), status: 400),
               stub_request(:delete,
                            'https://backend.global-registry.org/entities/51a014a4-4252-11e7-944f-129bd0521531')
                 .to_return(status: 200)]
            end

            it 'should delete relationship and retry' do
              expect do
                worker.push_relationship_to_global_registry
              end.to raise_error(GlobalRegistry::Bindings::RelatedEntityExistsWithCID)
              requests.each { |r| expect(r).to have_been_requested.once }
              expect(assignment.global_registry_id).to be_nil
            end
          end
        end
      end

      context 'related entities missing global_registry_id' do
        context '\'person\' missing global_registry_id' do
          let(:person) { build(:person) }
          let(:organization) { build(:organization, gr_id: 'aebb4170-3f34-11e7-bba6-129bd0521531') }
          let!(:assignment) { create(:assignment, person: person, organization: organization) }

          it 'should raise an exception' do
            clear_sidekiq_jobs_and_locks

            expect do
              worker.push_relationship_to_global_registry
            end.to raise_error(GlobalRegistry::Bindings::RelatedEntityMissingGlobalRegistryId).and(
              change(GlobalRegistry::Bindings::Workers::PushEntityWorker.jobs, :size).by(1)
            )
          end
        end

        context '\'organization\' missing global_registry_id' do
          let(:person) { build(:person, global_registry_id: '22527d88-3cba-11e7-b876-129bd0521531') }
          let(:organization) { build(:organization) }
          let!(:assignment) { create(:assignment, person: person, organization: organization) }

          it 'should raise an exception' do
            clear_sidekiq_jobs_and_locks

            expect do
              worker.push_relationship_to_global_registry
            end.to raise_error(GlobalRegistry::Bindings::RelatedEntityMissingGlobalRegistryId).and(
              change(GlobalRegistry::Bindings::Workers::PushEntityWorker.jobs, :size).by(1)
            )
          end
        end

        context '\'person\' and \'organization\' missing global_registry_id' do
          let(:person) { build(:person) }
          let(:organization) { build(:organization) }
          let!(:assignment) { create(:assignment, person: person, organization: organization) }

          it 'should raise an exception' do
            clear_sidekiq_jobs_and_locks

            expect do
              worker.push_relationship_to_global_registry
            end.to raise_error(GlobalRegistry::Bindings::RelatedEntityMissingGlobalRegistryId).and(
              change(GlobalRegistry::Bindings::Workers::PushEntityWorker.jobs, :size).by(2)
            )
          end
        end
      end
    end

    describe Organization do
      let(:worker) { GlobalRegistry::Bindings::Workers::PushRelationshipWorker.new organization, :area }
      context 'as create' do
        let(:area) { create(:area, global_registry_id: '0fdb70c5-f51e-4628-a1fe-caa37fae53cd') }
        let(:organization) { create(:organization, gr_id: 'aebb4170-3f34-11e7-bba6-129bd0521531', area: area) }
        let!(:requests) do
          [stub_request(:get, 'https://backend.global-registry.org/entity_types')
            .with(query: { 'filters[name]' => 'fancy_org', 'filters[parent_id]' => nil })
            .to_return(body: file_fixture('get_entity_types_fancy_org.json'), status: 200),
           stub_request(:get, 'https://backend.global-registry.org/entity_types')
             .with(query: { 'filters[name]' => 'area', 'filters[parent_id]' => nil })
             .to_return(body: file_fixture('get_entity_types_area.json'), status: 200),
           stub_request(:put, "https://backend.global-registry.org/entities/#{organization.gr_id}")
             .with(body: { entity: { fancy_org: { 'area:relationship': {
                     priority: 'High',
                     client_integration_id: organization.id,
                     client_updated_at: '2001-02-03 00:00:00', area: area.global_registry_id
                   } }, client_integration_id: organization.id } },
                   query: { full_response: 'true', fields: 'area:relationship' })
             .to_return(body: file_fixture('put_entities_fancy_org_relationship.json'), status: 200)]
        end

        context '\'area\' relationship_type does not exist' do
          let!(:sub_requests) do
            [stub_request(:get, 'https://backend.global-registry.org/relationship_types')
              .with(query: { 'filters[between]' =>
                                '025a1128-3f33-11e7-b876-129bd0521531,548852c6-d55e-11e3-897f-12725f8f377c' })
              .to_return(body: file_fixture('get_relationship_types.json'), status: 200),
             stub_request(:post, 'https://backend.global-registry.org/relationship_types')
               .with(body: { relationship_type: { entity_type1_id: '025a1128-3f33-11e7-b876-129bd0521531',
                                                  entity_type2_id: '548852c6-d55e-11e3-897f-12725f8f377c',
                                                  relationship1: 'fancy_org', relationship2: 'area' } })
               .to_return(body: file_fixture('post_relationship_types_fancy_org_area.json'), status: 200),
             stub_request(:put,
                          'https://backend.global-registry.org/relationship_types/f03b947e-6644-11e7-93dd-129bd0521531')
               .with(body: { relationship_type: { fields: [{ name: 'priority', field_type: 'string' }] } })
               .to_return(body: file_fixture('put_relationship_types_fields_fancy_org_area.json'), status: 200)]
          end

          it 'should create \'area\' relationship_type and push relationship' do
            worker.push_relationship_to_global_registry
            (requests + sub_requests).each { |r| expect(r).to have_been_requested.once }
            expect(organization.global_registry_area_id).to eq 'c99d7d7e-8b14-4fe6-9c11-e5359ee03637'
          end
        end
      end
    end

    describe Namespaced::Person do
      describe 'country_of_service' do
        let(:worker) { GlobalRegistry::Bindings::Workers::PushRelationshipWorker.new person, :country_of_service }
        context 'as create' do
          let(:country) { create(:country, global_registry_id: '0f9089a3-2b93-4de8-9b81-92be0261f325') }
          let(:person) do
            create(:person, global_registry_id: '2f0c62f1-5738-4860-88bd-5706fb801d7b', country_of_service: country)
          end
          let!(:request) do
            stub_request(:put, "https://backend.global-registry.org/entities/#{person.global_registry_id}")
              .with(body: { entity: { person: { 'country:relationship': {
                      client_integration_id: "cos_#{person.id}",
                      client_updated_at: '2001-02-03 00:00:00', country_of_service: true,
                      country: country.global_registry_id
                    } }, client_integration_id: person.id } },
                    query: { full_response: 'true', fields: 'country:relationship' })
              .to_return(body: file_fixture('put_entities_person_country_relationship.json'), status: 200)
          end

          it 'should push relationship' do
            worker.push_relationship_to_global_registry
            expect(request).to have_been_requested.once
            expect(person.country_of_service_gr_id).to eq '420d2fd1-7a73-41ed-9d8f-5dc79b00a688'
          end
        end
      end

      describe 'country_of_residence' do
        let(:worker) { GlobalRegistry::Bindings::Workers::PushRelationshipWorker.new person, :country_of_residence }
        context 'as create' do
          let(:country) { create(:country, global_registry_id: '7cdaf399-d449-4008-8c6b-3c64a2b2730c') }
          let(:person) do
            create(:person, global_registry_id: '2f0c62f1-5738-4860-88bd-5706fb801d7b', country_of_residence: country)
          end
          let!(:request) do
            stub_request(:put, "https://backend.global-registry.org/entities/#{person.global_registry_id}")
              .with(body: { entity: { person: { 'country:relationship': {
                      client_integration_id: "cor_#{person.id}",
                      client_updated_at: '2001-02-03 00:00:00', country_of_residence: true,
                      country: country.global_registry_id
                    } }, client_integration_id: person.id } },
                    query: { full_response: 'true', fields: 'country:relationship' })
              .to_return(body: file_fixture('put_entities_person_country_relationship.json'), status: 200)
          end

          it 'should push relationship' do
            worker.push_relationship_to_global_registry
            expect(request).to have_been_requested.once
            expect(person.country_of_residence_gr_id).to eq 'a4c030ce-13f2-44f5-8131-4003eb21c0ae'
          end
        end
      end
    end

    describe Community do
      let(:worker) { GlobalRegistry::Bindings::Workers::PushRelationshipWorker.new community, :infobase_ministry }
      let(:community) do
        create(:community, global_registry_id: '6133f6fe-c63a-425a-bb46-68917c689723', infobase_id: 2345)
      end
      let!(:request) do
        stub_request(:put, "https://backend.global-registry.org/entities/#{community.global_registry_id}")
          .with(body: { entity: { community: { 'ministry:relationship': {
                  client_integration_id: community.id, client_updated_at: '2001-02-03 00:00:00',
                  ministry: '41f767fd-86f4-42e2-8d24-cbc3f697b794'
                } }, client_integration_id: community.id } },
                query: { full_response: 'true', fields: 'ministry:relationship' })
          .to_return(body: file_fixture('put_entities_community_relationship.json'), status: 200)
      end

      it 'should push relationship' do
        worker.push_relationship_to_global_registry
        expect(request).to have_been_requested.once
        expect(community.infobase_gr_id).to eq 'ee40f9ed-d625-405b-8ce6-aec821611ec6'
      end
    end
  end
end
