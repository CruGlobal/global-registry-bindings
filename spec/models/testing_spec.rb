# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GlobalRegistry::Bindings::Testing do
  include WithQueueDefinition

  describe 'skip_workers! &block' do
    around(:example) do |example|
      GlobalRegistry::Bindings::Testing.skip_workers!(&example)
    end

    it 'should not enqueue ActiveJob jobs' do
      person = build(:person)
      expect do
        person.save
      end.to have_enqueued_job.exactly(0)
    end

    context 'disable_test_helper! &block' do
      it 'should enqueue ActiveJob jobs' do
        expect(GlobalRegistry::Bindings::Testing.enabled?).to be true
        GlobalRegistry::Bindings::Testing.disable_test_helper! do
          expect(GlobalRegistry::Bindings::Testing.enabled?).to be false
          expect(GlobalRegistry::Bindings::Testing.disabled?).to be true
          person = build(:person)
          expect do
            person.save
          end.to(have_enqueued_job(GlobalRegistry::Bindings::Workers::PushEntityWorker)
          .with do |*queued_params|
            expect(queued_params).to eq ['Namespaced::Person', 1]
          end.and(have_enqueued_job(GlobalRegistry::Bindings::Workers::PullNamespacedPersonMdmIdWorker)
              .with do |*queued_params|
                expect(queued_params).to eq ['Namespaced::Person', 1]
              end))
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

    it 'should not enqueue ActiveJob jobs' do
      person = build(:person)
      expect do
        person.save
      end.to have_enqueued_job.exactly(0)
    end
  end
end
