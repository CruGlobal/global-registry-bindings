# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GlobalRegistry::Bindings::Testing do
  describe 'skip_workers! &block' do
    around(:example) do |example|
      GlobalRegistry::Bindings::Testing.skip_workers!(&example)
    end

    it 'should not enqueue sidekiq jobs' do
      person = build(:person)
      expect do
        person.save
      end.to change(Sidekiq::Worker.jobs, :size).by(0)
    end

    context 'disable_test_helper! &block' do
      it 'should enqueue sidekiq jobs' do
        expect(GlobalRegistry::Bindings::Testing.enabled?).to be true
        GlobalRegistry::Bindings::Testing.disable_test_helper! do
          expect(GlobalRegistry::Bindings::Testing.enabled?).to be false
          expect(GlobalRegistry::Bindings::Testing.disabled?).to be true
          person = build(:person)
          expect do
            person.save
          end.to change(GlobalRegistry::Bindings::Workers::PushEntityWorker.jobs, :size).by(1).and(
            change(GlobalRegistry::Bindings::Workers::PullNamespacedPersonMdmIdWorker.jobs, :size).by(1).and(
              change(GlobalRegistry::Bindings::Workers::PushRelationshipWorker.jobs, :size).by(0).and(
                change(GlobalRegistry::Bindings::Workers::DeleteEntityWorker.jobs, :size).by(0)
              )
            )
          )
        end
        expect(GlobalRegistry::Bindings::Testing.enabled?).to be true
      end
    end
  end

  describe 'skip_workers! enable/disable' do
    before do
      GlobalRegistry::Bindings::Testing.skip_workers!
    end
    after do
      GlobalRegistry::Bindings::Testing.disable_test_helper!
    end

    it 'should not enqueue sidekiq jobs' do
      person = build(:person)
      expect do
        person.save
      end.to change(Sidekiq::Worker.jobs, :size).by(0)
    end
  end
end
