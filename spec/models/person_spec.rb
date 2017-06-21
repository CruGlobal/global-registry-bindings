# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Namespaced::Person do
  describe '#push_entity_to_global_registry_async' do
    it 'should enqueue sidekiq job' do
      person = build(:person)
      expect do
        person.push_entity_to_global_registry_async
      end.to change(GlobalRegistry::Bindings::Workers::PushEntityWorker.jobs, :size).by(1)
    end
  end

  describe '#delete_entity_from_global_registry_async' do
    it 'should enqueue sidekiq job' do
      person = build(:person, global_registry_id: '22527d88-3cba-11e7-b876-129bd0521531')
      expect do
        person.delete_entity_from_global_registry_async
      end.to change(GlobalRegistry::Bindings::Workers::DeleteEntityWorker.jobs, :size).by(1)
    end

    it 'should not enqueue sidekiq job when missing global_registry_id' do
      person = build(:person)
      expect do
        person.delete_entity_from_global_registry_async
      end.not_to change(GlobalRegistry::Bindings::Workers::DeleteEntityWorker.jobs, :size)
    end
  end

  describe '#pull_mdm_id_from_global_registry_async' do
    it 'should enqueue sidekiq job' do
      person = build(:person)
      expect do
        person.pull_mdm_id_from_global_registry_async
      end.to change(GlobalRegistry::Bindings::Workers::PullNamespacedPersonMdmIdWorker.jobs, :size).by(1)
    end
  end
end
