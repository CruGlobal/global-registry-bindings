# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Assignment do
  describe '#push_relationship_to_global_registry_async' do
    it 'should enqueue sidekiq job' do
      assignment = build(:assignment)
      expect do
        assignment.push_relationship_to_global_registry_async
      end.to change(GlobalRegistry::Bindings::Workers::PushRelationshipWorker.jobs, :size).by(1)
    end
  end
end
