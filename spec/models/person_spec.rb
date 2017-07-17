# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Namespaced::Person do
  describe 'after_commit on: :create' do
    context 'without associations' do
      it 'should enqueue sidekiq jobs' do
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
    end

    context 'with country_of_service' do
      it 'should enqueue sidekiq jobs' do
        country = build(:country)
        person = build(:person, country_of_service: country)
        expect do
          person.save
        end.to change(GlobalRegistry::Bindings::Workers::PushEntityWorker.jobs, :size).by(2).and(
          change(GlobalRegistry::Bindings::Workers::PullNamespacedPersonMdmIdWorker.jobs, :size).by(1).and(
            change(GlobalRegistry::Bindings::Workers::PushRelationshipWorker.jobs, :size).by(1).and(
              change(GlobalRegistry::Bindings::Workers::DeleteEntityWorker.jobs, :size).by(0)
            )
          )
        )
      end
    end

    context 'with country_of_residence' do
      it 'should enqueue sidekiq jobs' do
        country = build(:country)
        person = build(:person, country_of_residence: country)
        expect do
          person.save
        end.to change(GlobalRegistry::Bindings::Workers::PushEntityWorker.jobs, :size).by(2).and(
          change(GlobalRegistry::Bindings::Workers::PullNamespacedPersonMdmIdWorker.jobs, :size).by(1).and(
            change(GlobalRegistry::Bindings::Workers::PushRelationshipWorker.jobs, :size).by(1).and(
              change(GlobalRegistry::Bindings::Workers::DeleteEntityWorker.jobs, :size).by(0)
            )
          )
        )
      end
    end

    context 'with country_of_service and country_of_residence' do
      it 'should enqueue sidekiq jobs' do
        country = build(:country)
        person = build(:person, country_of_residence: country, country_of_service: country)
        expect do
          person.save
        end.to change(GlobalRegistry::Bindings::Workers::PushEntityWorker.jobs, :size).by(2).and(
          change(GlobalRegistry::Bindings::Workers::PullNamespacedPersonMdmIdWorker.jobs, :size).by(1).and(
            change(GlobalRegistry::Bindings::Workers::PushRelationshipWorker.jobs, :size).by(2).and(
              change(GlobalRegistry::Bindings::Workers::DeleteEntityWorker.jobs, :size).by(0)
            )
          )
        )
      end
    end
  end

  describe 'after_commit on: :update' do
    context 'update person attribute' do
      it 'should enqueue sidekiq jobs' do
        person = create(:person, global_registry_id: 'dd555dbf-f3db-4158-a50c-50d3f26347e8')
        clear_sidekiq_jobs_and_locks
        expect do
          person.first_name = 'Anthony'
          person.save
        end.to change(GlobalRegistry::Bindings::Workers::PushEntityWorker.jobs, :size).by(1).and(
          change(GlobalRegistry::Bindings::Workers::PullNamespacedPersonMdmIdWorker.jobs, :size).by(1).and(
            change(GlobalRegistry::Bindings::Workers::PushRelationshipWorker.jobs, :size).by(0).and(
              change(GlobalRegistry::Bindings::Workers::DeleteEntityWorker.jobs, :size).by(0)
            )
          )
        )
      end

      context 'with associations' do
        it 'should enqueue sidekiq jobs' do
          country = create(:country)
          person = create(:person, country_of_residence: country, country_of_service: country)
          clear_sidekiq_jobs_and_locks
          expect do
            person.first_name = 'Anthony'
            person.save
          end.to change(GlobalRegistry::Bindings::Workers::PushEntityWorker.jobs, :size).by(1).and(
            change(GlobalRegistry::Bindings::Workers::PullNamespacedPersonMdmIdWorker.jobs, :size).by(1).and(
              change(GlobalRegistry::Bindings::Workers::PushRelationshipWorker.jobs, :size).by(2).and(
                change(GlobalRegistry::Bindings::Workers::DeleteEntityWorker.jobs, :size).by(0)
              )
            )
          )
        end

        context 'country_of_residence removed' do
          it 'should enqueue sidekiq jobs' do
            country = create(:country)
            person = create(:person, country_of_residence: country, country_of_service: country,
                                     country_of_residence_gr_id: '4fa555dd-a067-478e-8765-8faa9483cc56')
            clear_sidekiq_jobs_and_locks
            expect do
              person.country_of_residence = nil
              person.save
            end.to change(GlobalRegistry::Bindings::Workers::PushEntityWorker.jobs, :size).by(1).and(
              change(GlobalRegistry::Bindings::Workers::PullNamespacedPersonMdmIdWorker.jobs, :size).by(1).and(
                change(GlobalRegistry::Bindings::Workers::PushRelationshipWorker.jobs, :size).by(1).and(
                  change(GlobalRegistry::Bindings::Workers::DeleteEntityWorker.jobs, :size).by(1)
                )
              )
            )
          end
        end

        context 'country_of_service changed' do
          it 'should enqueue sidekiq jobs' do
            country = create(:country, global_registry_id: 'f078eb70-5ddd-4941-9b06-a39576d9952f')
            country2 = create(:country, name: 'Peru', global_registry_id: 'f078eb70-5ddd-4941-9b06-a39576d9963c')
            person = create(:person, country_of_residence: country, country_of_service: country,
                                     country_of_residence_gr_id: '4fa555dd-a067-478e-8765-8faa9483cc56',
                                     country_of_service_gr_id: '89f81f6e-7baf-44d9-8f3a-55bf7c652dcc')
            request = stub_request(:delete,
                                   'https://backend.global-registry.org/entities/89f81f6e-7baf-44d9-8f3a-55bf7c652dcc')
                      .to_return(status: 200)

            clear_sidekiq_jobs_and_locks
            expect do
              person.country_of_service = country2
              person.save
            end.to change(GlobalRegistry::Bindings::Workers::PushEntityWorker.jobs, :size).by(1).and(
              change(GlobalRegistry::Bindings::Workers::PullNamespacedPersonMdmIdWorker.jobs, :size).by(1).and(
                change(GlobalRegistry::Bindings::Workers::PushRelationshipWorker.jobs, :size).by(2).and(
                  change(GlobalRegistry::Bindings::Workers::DeleteEntityWorker.jobs, :size).by(0)
                )
              )
            )
            expect(request).to have_been_requested.once
          end
        end
      end
    end
  end

  describe 'after_commit on: :destroy' do
    context 'without associations' do
      it 'should enqueue sidekiq jobs' do
        person = create(:person, global_registry_id: 'dd555dbf-f3db-4158-a50c-50d3f26347e8')
        clear_sidekiq_jobs_and_locks
        expect do
          person.destroy
        end.to change(GlobalRegistry::Bindings::Workers::PushEntityWorker.jobs, :size).by(0).and(
          change(GlobalRegistry::Bindings::Workers::PullNamespacedPersonMdmIdWorker.jobs, :size).by(0).and(
            change(GlobalRegistry::Bindings::Workers::PushRelationshipWorker.jobs, :size).by(0).and(
              change(GlobalRegistry::Bindings::Workers::DeleteEntityWorker.jobs, :size).by(1)
            )
          )
        )
      end
    end

    context 'with associations' do
      it 'should enqueue sidekiq jobs' do
        resident = create(:country, global_registry_id: 'f078eb70-5ddd-4941-9b06-a39576d9952f')
        employee = create(:country, global_registry_id: 'f078eb70-5ddd-4941-9b06-a39576d99639')
        person = create(:person, country_of_residence: resident, country_of_service: employee,
                                 global_registry_id: 'dd555dbf-f3db-4158-a50c-50d3f26347e8',
                                 country_of_residence_gr_id: '4fa555dd-a067-478e-8765-8faa9483cc56',
                                 country_of_service_gr_id: '89f81f6e-7baf-44d9-8f3a-55bf7c652dcc')
        clear_sidekiq_jobs_and_locks
        expect do
          person.destroy
        end.to change(GlobalRegistry::Bindings::Workers::PushEntityWorker.jobs, :size).by(0).and(
          change(GlobalRegistry::Bindings::Workers::PullNamespacedPersonMdmIdWorker.jobs, :size).by(0).and(
            change(GlobalRegistry::Bindings::Workers::PushRelationshipWorker.jobs, :size).by(0).and(
              change(GlobalRegistry::Bindings::Workers::DeleteEntityWorker.jobs, :size).by(3)
            )
          )
        )
      end
    end
  end
end
