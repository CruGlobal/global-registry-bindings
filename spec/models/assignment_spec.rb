# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Assignment do
  include WithQueueDefinition

  describe 'after_commit on: :create' do
    it 'should enqueue sidekiq job' do
      person = create(:person)
      organization = create(:organization)
      assignment = build(:assignment, person: person, organization: organization)

      expect do
        assignment.save
      end.to have_enqueued_job(GlobalRegistry::Bindings::Workers::PushRelationshipWorker).
          with do |*queued_params|
            expect(queued_params).to eq(["Assignment", 1, "fancy_org_assignment"])
      end
    end
  end

  describe 'after_commit on: :update' do
    it 'should enqueue sidekiq job' do
      person = create(:person)
      organization = create(:organization)
      assignment = create(:assignment, person: person, organization: organization)

      expect do
        assignment.role = 'boss'
        assignment.save
      end.to have_enqueued_job(GlobalRegistry::Bindings::Workers::PushRelationshipWorker).
          with do |*queued_params|
        expect(queued_params).to eq(["Assignment", 1, "fancy_org_assignment"])
      end
    end
  end

  describe 'after_commit on: :destroy' do
    it 'should enqueue sidekiq job' do
      person = create(:person)
      organization = create(:organization)
      assignment = create(:assignment, person: person, organization: organization, global_registry_id: 'abc')

      expect do
        assignment.destroy
      end.to have_enqueued_job(GlobalRegistry::Bindings::Workers::DeleteEntityWorker).
          with do |*queued_params|
        expect(queued_params).to eq(['abc'])
      end
    end
  end
end
