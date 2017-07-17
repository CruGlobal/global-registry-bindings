# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Assignment do
  describe 'after_commit on: :create' do
    it 'should enqueue sidekiq job' do
      person = create(:person)
      organization = create(:organization)
      assignment = build(:assignment, person: person, organization: organization)
      clear_sidekiq_jobs_and_locks
      expect do
        assignment.save
      end.to change(GlobalRegistry::Bindings::Workers::PushEntityWorker.jobs, :size).by(0).and(
        change(GlobalRegistry::Bindings::Workers::PushRelationshipWorker.jobs, :size).by(1).and(
          change(GlobalRegistry::Bindings::Workers::DeleteEntityWorker.jobs, :size).by(0)
        )
      )
    end
  end

  describe 'after_commit on: :update' do
    it 'should enqueue sidekiq job' do
      person = create(:person)
      organization = create(:organization)
      assignment = create(:assignment, person: person, organization: organization)
      clear_sidekiq_jobs_and_locks
      expect do
        assignment.role = 'boss'
        assignment.save
      end.to change(GlobalRegistry::Bindings::Workers::PushEntityWorker.jobs, :size).by(0).and(
        change(GlobalRegistry::Bindings::Workers::PushRelationshipWorker.jobs, :size).by(1).and(
          change(GlobalRegistry::Bindings::Workers::DeleteEntityWorker.jobs, :size).by(0)
        )
      )
    end
  end

  describe 'after_commit on: :destroy' do
    it 'should enqueue sidekiq job' do
      person = create(:person)
      organization = create(:organization)
      assignment = create(:assignment, person: person, organization: organization, global_registry_id: 'abc')
      clear_sidekiq_jobs_and_locks
      expect do
        assignment.destroy
      end.to change(GlobalRegistry::Bindings::Workers::PushEntityWorker.jobs, :size).by(0).and(
        change(GlobalRegistry::Bindings::Workers::PushRelationshipWorker.jobs, :size).by(0).and(
          change(GlobalRegistry::Bindings::Workers::DeleteEntityWorker.jobs, :size).by(1)
        )
      )
    end
  end
end
