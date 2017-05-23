# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Organization' do
  describe ':async_push_entity_to_global_registry' do
    it 'should enqueue sidekiq job' do
      org = build(:organization)
      expect do
        org.async_push_entity_to_global_registry
      end.to change(GlobalRegistry::Bindings::Workers::PushGrEntityWorker.jobs, :size).by(1)
    end
  end

  describe ':async_delete_from_global_registry' do
    it 'should enqueue sidekiq job' do
      organization = build(:organization, gr_id: '22527d88-3cba-11e7-b876-129bd0521531')
      expect do
        organization.async_delete_from_global_registry
      end.to change(GlobalRegistry::Bindings::Workers::DeleteGrEntityWorker.jobs, :size).by(1)
    end

    it 'should not enqueue sidekiq job when missing global_registry_id' do
      organization = build(:organization)
      expect do
        organization.async_delete_from_global_registry
      end.not_to change(GlobalRegistry::Bindings::Workers::DeleteGrEntityWorker.jobs, :size)
    end
  end

  describe ':push_entity_to_global_registry' do
    around { |example| travel_to Time.utc(2001, 2, 3), &example }
    context 'create' do
      context '\'fancy_org\' entity_type does not exist' do
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

        context 'orphan record' do
          let(:organization) { create(:organization) }
          let!(:sub_requests) do
            [stub_request(:post, 'https://backend.global-registry.org/entities')
              .with(body: { entity: { fancy_org: { name: 'Organization', description: 'Fancy Organization',
                                                   start_date: '2001-02-03', parent_id: nil,
                                                   client_integration_id: organization.id,
                                                   client_updated_at: '2001-02-03 00:00:00' } } })
              .to_return(body: file_fixture('post_entities_fancy_org.json'), status: 200)]
          end

          it 'should create \'fancy_org\' entity_type and push entity' do
            organization.push_entity_to_global_registry
            (requests + sub_requests).each { |r| expect(r).to have_been_requested.once }
            expect(organization.gr_id).to eq 'aebb4170-3f34-11e7-bba6-129bd0521531'
          end
        end

        context 'record with a parent' do
          let(:parent) { create(:organization, name: 'Parent', description: 'Parent Fancy Organization') }
          let(:organization) { create(:organization, parent: parent) }
          let!(:sub_requests) do
            [stub_request(:post, 'https://backend.global-registry.org/entities')
              .with(body: { entity: { fancy_org: { name: 'Parent', description: 'Parent Fancy Organization',
                                                   start_date: '2001-02-03', parent_id: nil,
                                                   client_integration_id: parent.id,
                                                   client_updated_at: '2001-02-03 00:00:00' } } })
              .to_return(body: file_fixture('post_entities_fancy_org_parent.json'), status: 200),
             stub_request(:post, 'https://backend.global-registry.org/entities')
               .with(body: { entity: { fancy_org: { name: 'Organization', description: 'Fancy Organization',
                                                    start_date: '2001-02-03',
                                                    parent_id: 'cd5da38a-c336-46a7-b818-dcdd51c4acde',
                                                    client_integration_id: organization.id,
                                                    client_updated_at: '2001-02-03 00:00:00' } } })
               .to_return(body: file_fixture('post_entities_fancy_org.json'), status: 200)]
          end

          it 'should create \'fancy_org\' entity_type and push both entities' do
            organization.push_entity_to_global_registry
            (requests + sub_requests).each { |r| expect(r).to have_been_requested.once }
            expect(parent.gr_id).to eq 'cd5da38a-c336-46a7-b818-dcdd51c4acde'
            expect(organization.gr_id).to eq 'aebb4170-3f34-11e7-bba6-129bd0521531'
          end
        end

        context 'record with an exiting parent' do
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
            organization.push_entity_to_global_registry
            (requests + sub_requests).each { |r| expect(r).to have_been_requested.once }
            expect(parent.gr_id).to eq 'cd5da38a-c336-46a7-b818-dcdd51c4acde'
            expect(organization.gr_id).to eq 'aebb4170-3f34-11e7-bba6-129bd0521531'
          end
        end
      end
    end
  end
end
