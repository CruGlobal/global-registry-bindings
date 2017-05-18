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
    let(:person) { create(:person) }

    context '\'person\' entity_type does not exist' do
      let!(:requests) do
        [stub_request(:get, 'https://backend.global-registry.org/entity_types')
          .with(query: { 'filters[name]' => 'person', 'filters[parent_id]' => nil })
          .to_return(body: file_fixture('get_entity_types.json').read, status: 200),
         stub_request(:post, 'https://backend.global-registry.org/entity_types')
           .with(body: { entity_type: { name: 'person', parent_id: nil, field_type: 'entity' } })
           .to_return(body: file_fixture('post_entity_types_person.json').read, status: 200),
         stub_request(:post, 'https://backend.global-registry.org/entity_types')
           .with(body: { entity_type: { name: 'first_name', parent_id: 'ee13a693-3ce7-4c19-b59a-30c8f137acd8',
                                        field_type: 'string' } })
           .to_return(status: 200),
         stub_request(:post, 'https://backend.global-registry.org/entity_types')
           .with(body: { entity_type: { name: 'last_name', parent_id: 'ee13a693-3ce7-4c19-b59a-30c8f137acd8',
                                        field_type: 'string' } })
           .to_return(status: 200)]
      end

      it 'should create \'person\' entity_type' do
        person.push_entity_to_global_registry
        requests.each { |r| expect(r).to have_been_requested }
      end
    end

    # context '\'person\' entity_type exists' do
    #
    # end

    context '\'person\' entity_type is cached' do
      before :each do
        person_entity_types = JSON.parse(file_fixture('get_entity_type_person.json').read)
        Rails.cache.write('GlobalRegistry::Bindings::EntityType::person', person_entity_types['entity_types'].first)
      end

      it 'should skip creating entity_type' do
        person.push_entity_to_global_registry
      end
    end
  end
end
