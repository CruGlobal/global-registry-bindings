# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Namespaced::Person do
  include WithQueueDefinition

  describe 'after_commit on: :create' do
    context 'without associations' do
      it 'should enqueue sidekiq jobs' do
        person = build(:person)
        expect do
          person.save
        end.to(have_enqueued_job(GlobalRegistry::Bindings::Workers::PushEntityWorker)
            .with do |*queued_params|
              expect(queued_params).to eq ['Namespaced::Person', 1]
            end.and(have_enqueued_job(GlobalRegistry::Bindings::Workers::PullNamespacedPersonMdmIdWorker)
            .with do |*queued_params|
              expect(queued_params).to eq ['Namespaced::Person', 1]
            end
            .and(have_enqueued_job(GlobalRegistry::Bindings::Workers::PushRelationshipWorker).exactly(0)
            .and(have_enqueued_job(GlobalRegistry::Bindings::Workers::DeleteEntityWorker).exactly(0)))))
      end
    end

    context 'with country_of_service' do
      it 'should enqueue sidekiq jobs' do
        results = [
          ['Namespaced::Person', 1],
          ['Country', 1]
        ]
        country = build(:country)
        person = build(:person, country_of_service: country)
        expect do
          person.save
        end.to(have_enqueued_job(GlobalRegistry::Bindings::Workers::PushEntityWorker).exactly(2)
            .with do |*queued_params|
              expect(queued_params).to be_in(results)
              results.delete(queued_params)
            end.and(have_enqueued_job(GlobalRegistry::Bindings::Workers::PullNamespacedPersonMdmIdWorker)
            .with do |*queued_params|
              expect(queued_params).to eq ['Namespaced::Person', 1]
            end.and(have_enqueued_job(GlobalRegistry::Bindings::Workers::PushRelationshipWorker)
            .with do |*queued_params|
              expect(queued_params).to eq ['Namespaced::Person', 1, 'country_of_service']
            end
            .and(have_enqueued_job(GlobalRegistry::Bindings::Workers::DeleteEntityWorker).exactly(0)))))
        expect(results).to be_empty
      end
    end

    context 'with country_of_residence' do
      it 'should enqueue sidekiq jobs' do
        results = [
          ['Namespaced::Person', 1],
          ['Country', 1]
        ]
        country = build(:country)
        person = build(:person, country_of_residence: country)
        expect do
          person.save
        end.to(have_enqueued_job(GlobalRegistry::Bindings::Workers::PushEntityWorker).exactly(2)
            .with do |*queued_params|
              expect(queued_params).to be_in(results)
              results.delete(queued_params)
            end.and(have_enqueued_job(GlobalRegistry::Bindings::Workers::PullNamespacedPersonMdmIdWorker)
            .with do |*queued_params|
              expect(queued_params).to eq ['Namespaced::Person', 1]
            end.and(have_enqueued_job(GlobalRegistry::Bindings::Workers::PushRelationshipWorker)
            .with do |*queued_params|
              expect(queued_params).to eq ['Namespaced::Person', 1, 'country_of_residence']
            end
            .and(have_enqueued_job(GlobalRegistry::Bindings::Workers::DeleteEntityWorker).exactly(0)))))
        expect(results).to be_empty
      end
    end

    context 'with country_of_service and country_of_residence' do
      it 'should enqueue sidekiq jobs' do
        results = [
          ['Namespaced::Person', 1],
          ['Country', 1]
        ]
        results_relationship = [
          ['Namespaced::Person', 1, 'country_of_service'],
          ['Namespaced::Person', 1, 'country_of_residence']
        ]
        country = build(:country)
        person = build(:person, country_of_residence: country, country_of_service: country)
        expect do
          person.save
        end.to(have_enqueued_job(GlobalRegistry::Bindings::Workers::PushEntityWorker).exactly(2)
            .with do |*queued_params|
              expect(queued_params).to be_in(results)
              results.delete(queued_params)
            end.and(have_enqueued_job(GlobalRegistry::Bindings::Workers::PushRelationshipWorker).exactly(2)
            .with do |*queued_params|
              expect(queued_params).to be_in(results_relationship)
              results_relationship.delete(queued_params)
            end.and(have_enqueued_job(GlobalRegistry::Bindings::Workers::PullNamespacedPersonMdmIdWorker)
            .with do |*queued_params|
              expect(queued_params).to eq ['Namespaced::Person', 1]
            end
            .and(have_enqueued_job(GlobalRegistry::Bindings::Workers::DeleteEntityWorker).exactly(0)))))
        expect(results).to be_empty
        expect(results_relationship).to be_empty
      end
    end
  end

  describe 'after_commit on: :update' do
    context 'update person attribute' do
      it 'should enqueue sidekiq jobs' do
        person = create(:person, global_registry_id: 'dd555dbf-f3db-4158-a50c-50d3f26347e8')
        expect do
          person.first_name = 'Anthony'
          person.save
        end.to(have_enqueued_job(GlobalRegistry::Bindings::Workers::PushEntityWorker)
           .with do |*queued_params|
             expect(queued_params).to eq ['Namespaced::Person', 1]
           end.and(have_enqueued_job(GlobalRegistry::Bindings::Workers::PullNamespacedPersonMdmIdWorker)
           .with do |*queued_params|
             expect(queued_params).to eq ['Namespaced::Person', 1]
           end
        .and(have_enqueued_job(GlobalRegistry::Bindings::Workers::PushRelationshipWorker).exactly(0)
        .and(have_enqueued_job(GlobalRegistry::Bindings::Workers::DeleteEntityWorker).exactly(0)))))
      end

      context 'with associations' do
        it 'should enqueue sidekiq jobs' do
          results_relationship = [
            ['Namespaced::Person', 1, 'country_of_service'],
            ['Namespaced::Person', 1, 'country_of_residence']
          ]
          country = create(:country)
          person = create(:person, country_of_residence: country, country_of_service: country)
          expect do
            person.first_name = 'Anthony'
            person.save
          end.to(have_enqueued_job(GlobalRegistry::Bindings::Workers::PushEntityWorker)
              .with do |*queued_params|
                expect(queued_params).to eq ['Namespaced::Person', 1]
              end.and(have_enqueued_job(GlobalRegistry::Bindings::Workers::PullNamespacedPersonMdmIdWorker)
              .with do |*queued_params|
                expect(queued_params).to eq ['Namespaced::Person', 1]
              end.and(have_enqueued_job(GlobalRegistry::Bindings::Workers::PushRelationshipWorker).exactly(2)
              .with do |*queued_params|
                expect(queued_params).to be_in(results_relationship)
                results_relationship.delete(queued_params)
              end
              .and(have_enqueued_job(GlobalRegistry::Bindings::Workers::DeleteEntityWorker).exactly(0)))))
          expect(results_relationship).to be_empty
        end

        context 'country_of_residence removed' do
          it 'should enqueue sidekiq jobs' do
            country = create(:country)
            person = create(:person, country_of_residence: country, country_of_service: country,
                                     country_of_residence_gr_id: '4fa555dd-a067-478e-8765-8faa9483cc56')
            expect do
              person.country_of_residence = nil
              person.save
            end.to(have_enqueued_job(GlobalRegistry::Bindings::Workers::PushEntityWorker)
                .with do |*queued_params|
                  expect(queued_params).to eq ['Namespaced::Person', 1]
                end.and(have_enqueued_job(GlobalRegistry::Bindings::Workers::PullNamespacedPersonMdmIdWorker)
                .with do |*queued_params|
                  expect(queued_params).to eq ['Namespaced::Person', 1]
                end.and(have_enqueued_job(GlobalRegistry::Bindings::Workers::PushRelationshipWorker)
                .with do |*queued_params|
                  expect(queued_params).to eq ['Namespaced::Person', 1, 'country_of_service']
                end
                .and(have_enqueued_job(GlobalRegistry::Bindings::Workers::DeleteEntityWorker)
                    .with do |*queued_params|
                      expect(queued_params).to eq ['4fa555dd-a067-478e-8765-8faa9483cc56']
                    end))))
          end
        end

        context 'country_of_service changed' do
          it 'should enqueue sidekiq jobs' do
            results_relationship = [
              ['Namespaced::Person', 1, 'country_of_service'],
              ['Namespaced::Person', 1, 'country_of_residence']
            ]
            country = create(:country, global_registry_id: 'f078eb70-5ddd-4941-9b06-a39576d9952f')
            country2 = create(:country, name: 'Peru', global_registry_id: 'f078eb70-5ddd-4941-9b06-a39576d9963c')
            person = create(:person, country_of_residence: country, country_of_service: country,
                                     country_of_residence_gr_id: '4fa555dd-a067-478e-8765-8faa9483cc56',
                                     country_of_service_gr_id: '89f81f6e-7baf-44d9-8f3a-55bf7c652dcc')
            stub_request(
              :delete,
              'https://backend.global-registry.org/entities/89f81f6e-7baf-44d9-8f3a-55bf7c652dcc'
            ).to_return(status: 200)

            expect do
              person.country_of_service = country2
              person.save
            end.to(have_enqueued_job(GlobalRegistry::Bindings::Workers::PushEntityWorker)
                .with do |*queued_params|
                  expect(queued_params).to eq ['Namespaced::Person', 1]
                end.and(have_enqueued_job(GlobalRegistry::Bindings::Workers::PullNamespacedPersonMdmIdWorker)
                .with do |*queued_params|
                  expect(queued_params).to eq ['Namespaced::Person', 1]
                end.and(have_enqueued_job(GlobalRegistry::Bindings::Workers::PushRelationshipWorker).exactly(2)
                .with do |*queued_params|
                  expect(queued_params).to be_in(results_relationship)
                  results_relationship.delete(queued_params)
                end
                .and(have_enqueued_job(GlobalRegistry::Bindings::Workers::DeleteEntityWorker).exactly(0)))))
            expect(results_relationship).to be_empty
          end
        end
      end
    end
  end

  describe 'after_commit on: :destroy' do
    context 'without associations' do
      it 'should enqueue sidekiq jobs' do
        person = create(:person, global_registry_id: 'dd555dbf-f3db-4158-a50c-50d3f26347e8')
        expect do
          person.destroy
        end.to(have_enqueued_job(GlobalRegistry::Bindings::Workers::DeleteEntityWorker)
            .with do |*queued_params|
              expect(queued_params).to eq ['dd555dbf-f3db-4158-a50c-50d3f26347e8']
            end
            .and(have_enqueued_job(GlobalRegistry::Bindings::Workers::PushEntityWorker).exactly(0)
            .and(have_enqueued_job(GlobalRegistry::Bindings::Workers::PushRelationshipWorker).exactly(0)
            .and(have_enqueued_job(GlobalRegistry::Bindings::Workers::PullNamespacedPersonMdmIdWorker).exactly(0)))))
      end
    end

    context 'with associations' do
      it 'should enqueue sidekiq jobs' do
        results_delete = [
          ['dd555dbf-f3db-4158-a50c-50d3f26347e8'],
          ['89f81f6e-7baf-44d9-8f3a-55bf7c652dcc'],
          ['4fa555dd-a067-478e-8765-8faa9483cc56']
        ]
        resident = create(:country, global_registry_id: 'f078eb70-5ddd-4941-9b06-a39576d9952f')
        employee = create(:country, global_registry_id: 'f078eb70-5ddd-4941-9b06-a39576d99639')
        person = create(:person, country_of_residence: resident, country_of_service: employee,
                                 global_registry_id: 'dd555dbf-f3db-4158-a50c-50d3f26347e8',
                                 country_of_residence_gr_id: '4fa555dd-a067-478e-8765-8faa9483cc56',
                                 country_of_service_gr_id: '89f81f6e-7baf-44d9-8f3a-55bf7c652dcc')
        expect do
          person.destroy
        end.to(have_enqueued_job(GlobalRegistry::Bindings::Workers::DeleteEntityWorker).exactly(3)
            .with do |*queued_params|
              expect(queued_params).to be_in(results_delete)
              results_delete.delete(queued_params)
            end
            .and(have_enqueued_job(GlobalRegistry::Bindings::Workers::PushEntityWorker).exactly(0)
            .and(have_enqueued_job(GlobalRegistry::Bindings::Workers::PushRelationshipWorker).exactly(0)
            .and(have_enqueued_job(GlobalRegistry::Bindings::Workers::PullNamespacedPersonMdmIdWorker).exactly(0)))))
        expect(results_delete).to be_empty
      end
    end
  end
end
