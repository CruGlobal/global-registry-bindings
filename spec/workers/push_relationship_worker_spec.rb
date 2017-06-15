# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'GlobalRegistry::Bindings::Workers' do
  describe 'PushRelationshipWorker' do
    let(:user) { create(:person) }

    it 'sends :push_relationship_to_global_registry to the model instance' do
      allow(Namespaced::Person).to receive(:push_relationship_to_global_registry)
      expect(Namespaced::Person).to receive(:find).with(user.id).and_return(user)
      expect(user).to receive(:push_relationship_to_global_registry)

      worker = GlobalRegistry::Bindings::Workers::PushRelationshipWorker.new
      worker.perform(Namespaced::Person, user.id)
    end

    it 'fails silently on ActiveRecord::RecordNotFound' do
      allow(Namespaced::Person).to receive(:push_relationship_to_global_registry)
      expect(Namespaced::Person).to receive(:find).with(user.id).and_raise(ActiveRecord::RecordNotFound)
      expect(user).not_to receive(:push_relationship_to_global_registry)

      worker = GlobalRegistry::Bindings::Workers::PushRelationshipWorker.new
      worker.perform('Namespaced::Person', user.id)
    end
  end
end
