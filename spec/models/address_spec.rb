# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Address do
  describe '#push_entity_to_global_registry_async' do
    it 'should enqueue sidekiq job' do
      address = build(:address)
      expect{
        address.push_entity_to_global_registry_async
      }.to have_enqueued_job.with{ |*queued_params|
        expect(queued_params).to eq ["Address", nil]
      }
    end
  end

  describe '#delete_entity_from_global_registry_async' do
    it 'should enqueue sidekiq job' do
      address = build(:address, global_registry_id: '22527d88-3cba-11e7-b876-129bd0521531')
      expect{
        address.delete_entity_from_global_registry_async
      }.to have_enqueued_job.with{ |*queued_params|
        expect(queued_params).to eq ['22527d88-3cba-11e7-b876-129bd0521531']
      }
    end

    it 'should not enqueue sidekiq job when missing global_registry_id' do
      address = build(:address)
      expect{
        address.delete_entity_from_global_registry_async
      }.not_to have_enqueued_job.with{ |*queued_params|
        expect(queued_params).to eq ['abcd']
      }
    end

    it 'should have a job definition in class config' do
      address = build(:address)
      expect(address.class._global_registry_bindings_options[:entity]).to be_a Hash
      expect(address.class._global_registry_bindings_options[:entity][:job]).to eq({queue: :default})
    end
  end
end
