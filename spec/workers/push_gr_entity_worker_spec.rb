# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'GlobalRegistry::Bindings::Workers' do
  describe 'PushGrEntityWorker' do
    let(:user) { create(:person) }

    it 'sends :push_entity_to_global_registry to the model instance' do
      allow(Namespaced::Person).to receive(:push_entity_to_global_registry_async)
      expect(Namespaced::Person).to receive(:find).with(user.id).and_return(user)
      expect(user).to receive(:push_entity_to_global_registry)

      worker = GlobalRegistry::Bindings::Workers::PushGrEntityWorker.new
      worker.perform('Namespaced::Person', user.id)
    end

    it 'fails silently on ActiveRecord::RecordNotFound' do
      allow(Namespaced::Person).to receive(:push_entity_to_global_registry_async)
      expect(Namespaced::Person).to receive(:find).with(user.id).and_raise(ActiveRecord::RecordNotFound)
      expect(user).not_to receive(:push_entity_to_global_registry)

      worker = GlobalRegistry::Bindings::Workers::PushGrEntityWorker.new
      worker.perform(Namespaced::Person, user.id)
    end
  end
end
