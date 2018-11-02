# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Organization do
  include WithQueueDefinition

  describe 'after_commit on: :create' do
    context 'without parent' do
      it 'should enqueue sidekiq jobs' do
        organization = build(:organization)
        expect do
          organization.save
        end.to(have_enqueued_job(GlobalRegistry::Bindings::Workers::PushEntityWorker)
          .with do |*queued_params|
            expect(queued_params).to eq ['Organization', 1]
          end
        .and(have_enqueued_job(GlobalRegistry::Bindings::Workers::PushRelationshipWorker).exactly(0)
        .and(have_enqueued_job(GlobalRegistry::Bindings::Workers::DeleteEntityWorker).exactly(0))))
      end

      context 'with area' do
        it 'should enqueue activejob jobs' do
          results = [
            ['Organization', 1],
            ['Area', 1]
          ]
          area = build(:area)
          organization = build(:organization, area: area)
          expect do
            organization.save
          end.to(have_enqueued_job(GlobalRegistry::Bindings::Workers::PushEntityWorker).exactly(2)
            .with do |*queued_params|
              expect(queued_params).to be_in(results)
              results.delete(queued_params)
            end.and(have_enqueued_job(GlobalRegistry::Bindings::Workers::PushRelationshipWorker)
              .with do |*queued_params|
                expect(queued_params).to eq ['Organization', 1, 'area']
              end
          .and(have_enqueued_job(GlobalRegistry::Bindings::Workers::DeleteEntityWorker).exactly(0))))
          expect(results).to be_empty
        end
      end
    end

    context 'with parent' do
      it 'should enqueue sidekiq jobs' do
        parent = build(:organization)
        organization = build(:organization, parent: parent)
        expect do
          organization.save
        end.to(have_enqueued_job(GlobalRegistry::Bindings::Workers::PushEntityWorker).exactly(2)
        .with do |*queued_params|
          expect(queued_params.first).to eq 'Organization'
          expect(queued_params.second).to be_in [1, 2]
        end
        .and(have_enqueued_job(GlobalRegistry::Bindings::Workers::DeleteEntityWorker).exactly(0)
        .and(have_enqueued_job(GlobalRegistry::Bindings::Workers::PushRelationshipWorker).exactly(0))))
      end

      context 'with area' do
        it 'should enqueue sidekiq jobs' do
          results = [
            ['Area', 1],
            ['Organization', 2],
            ['Organization', 1]
          ]

          area = build(:area)
          parent = build(:organization)
          organization = build(:organization, area: area, parent: parent)
          expect do
            organization.save
          end.to(have_enqueued_job(GlobalRegistry::Bindings::Workers::PushEntityWorker).exactly(3)
          .with do |*queued_params|
            expect(queued_params).to be_in(results)
            results.delete(queued_params)
          end.and(have_enqueued_job(GlobalRegistry::Bindings::Workers::PushRelationshipWorker)
             .with do |*queued_params|
               expect(queued_params).to eq ['Organization', 2, 'area']
             end
            .and(have_enqueued_job(GlobalRegistry::Bindings::Workers::DeleteEntityWorker).exactly(0))))
          expect(results).to be_empty
        end
      end
    end
  end

  describe 'after_commit on: :destroy' do
    context 'without parent' do
      it 'should enqueue sidekiq jobs' do
        organization = create(:organization, gr_id: 'abc')
        expect do
          organization.destroy
        end.to have_enqueued_job(GlobalRegistry::Bindings::Workers::DeleteEntityWorker)
          .with { |*queued_params|
            expect(queued_params).to eq ['abc']
          }
          .and have_enqueued_job(GlobalRegistry::Bindings::Workers::PushRelationshipWorker).exactly(0)
          .and have_enqueued_job(GlobalRegistry::Bindings::Workers::PushEntityWorker).exactly(0)
      end

      context 'with area' do
        it 'should enqueue sidekiq jobs' do
          results = [
            ['ijk'],
            ['abc']
          ]
          area = create(:area, global_registry_id: 'efg')
          organization = create(:organization, area: area, gr_id: 'abc', global_registry_area_id: 'ijk')
          expect do
            organization.destroy
          end.to(have_enqueued_job(GlobalRegistry::Bindings::Workers::DeleteEntityWorker).exactly(2)
            .with do |*queued_params|
              expect(queued_params).to be_in(results)
              results.delete(queued_params)
            end.and(have_enqueued_job(GlobalRegistry::Bindings::Workers::PushRelationshipWorker).exactly(0)
            .and(have_enqueued_job(GlobalRegistry::Bindings::Workers::PushEntityWorker).exactly(0))))
          expect(results).to be_empty
        end
      end
    end

    context 'with parent' do
      it 'should enqueue sidekiq jobs' do
        parent = create(:organization, gr_id: 'xyz')
        organization = create(:organization, parent: parent, gr_id: 'abc')
        expect do
          organization.destroy
        end.to(have_enqueued_job(GlobalRegistry::Bindings::Workers::DeleteEntityWorker)
            .with do |*queued_params|
              expect(queued_params).to eq ['abc']
            end
            .and(have_enqueued_job(GlobalRegistry::Bindings::Workers::PushRelationshipWorker).exactly(0)
            .and(have_enqueued_job(GlobalRegistry::Bindings::Workers::PushEntityWorker).exactly(0))))
      end

      context 'with area' do
        it 'should enqueue sidekiq jobs' do
          results = [
            ['abc'],
            ['ijk']
          ]
          area = create(:area, global_registry_id: 'efg')
          parent = create(:organization, gr_id: 'xyz')
          organization = create(:organization, area: area, gr_id: 'abc', global_registry_area_id: 'ijk', parent: parent)
          expect do
            organization.destroy
          end.to(have_enqueued_job(GlobalRegistry::Bindings::Workers::DeleteEntityWorker).exactly(2)
                .with do |*queued_params|
                  expect(queued_params).to be_in(results)
                  results.delete(queued_params)
                end
                .and(have_enqueued_job(GlobalRegistry::Bindings::Workers::PushRelationshipWorker).exactly(0)
                .and(have_enqueued_job(GlobalRegistry::Bindings::Workers::PushEntityWorker).exactly(0))))
          expect(results).to be_empty
        end
      end
    end
  end
end
