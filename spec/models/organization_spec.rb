# frozen_string_literal: true

require "spec_helper"

RSpec.describe Organization do
  describe "after_commit on: :create" do
    context "without parent" do
      it "should enqueue sidekiq jobs" do
        organization = build(:organization)
        expect do
          organization.save
        end.to change(GlobalRegistry::Bindings::Workers::PushEntityWorker.jobs, :size).by(1).and(
          change(GlobalRegistry::Bindings::Workers::PushRelationshipWorker.jobs, :size).by(0).and(
            change(GlobalRegistry::Bindings::Workers::DeleteEntityWorker.jobs, :size).by(0)
          )
        )
      end

      context "with area" do
        it "should enqueue sidekiq jobs" do
          area = build(:area)
          organization = build(:organization, area: area)
          expect do
            organization.save
          end.to change(GlobalRegistry::Bindings::Workers::PushEntityWorker.jobs, :size).by(2).and(
            change(GlobalRegistry::Bindings::Workers::PushRelationshipWorker.jobs, :size).by(1).and(
              change(GlobalRegistry::Bindings::Workers::DeleteEntityWorker.jobs, :size).by(0)
            )
          )
        end
      end
    end

    context "with parent" do
      it "should enqueue sidekiq jobs" do
        parent = build(:organization)
        organization = build(:organization, parent: parent)
        expect do
          organization.save
        end.to change(GlobalRegistry::Bindings::Workers::PushEntityWorker.jobs, :size).by(2).and(
          change(GlobalRegistry::Bindings::Workers::PushRelationshipWorker.jobs, :size).by(0).and(
            change(GlobalRegistry::Bindings::Workers::DeleteEntityWorker.jobs, :size).by(0)
          )
        )
      end

      context "with area" do
        it "should enqueue sidekiq jobs" do
          area = build(:area)
          parent = build(:organization)
          organization = build(:organization, area: area, parent: parent)
          expect do
            organization.save
          end.to change(GlobalRegistry::Bindings::Workers::PushEntityWorker.jobs, :size).by(3).and(
            change(GlobalRegistry::Bindings::Workers::PushRelationshipWorker.jobs, :size).by(1).and(
              change(GlobalRegistry::Bindings::Workers::DeleteEntityWorker.jobs, :size).by(0)
            )
          )
        end
      end
    end
  end

  describe "after_commit on: :destroy" do
    context "without parent" do
      it "should enqueue sidekiq jobs" do
        organization = create(:organization, gr_id: "abc")
        clear_sidekiq_jobs_and_locks
        expect do
          organization.destroy
        end.to change(GlobalRegistry::Bindings::Workers::PushEntityWorker.jobs, :size).by(0).and(
          change(GlobalRegistry::Bindings::Workers::PushRelationshipWorker.jobs, :size).by(0).and(
            change(GlobalRegistry::Bindings::Workers::DeleteEntityWorker.jobs, :size).by(1)
          )
        )
      end

      context "with area" do
        it "should enqueue sidekiq jobs" do
          area = create(:area, global_registry_id: "efg")
          organization = create(:organization, area: area, gr_id: "abc", global_registry_area_id: "ijk")
          clear_sidekiq_jobs_and_locks
          expect do
            organization.destroy
          end.to change(GlobalRegistry::Bindings::Workers::PushEntityWorker.jobs, :size).by(0).and(
            change(GlobalRegistry::Bindings::Workers::PushRelationshipWorker.jobs, :size).by(0).and(
              change(GlobalRegistry::Bindings::Workers::DeleteEntityWorker.jobs, :size).by(2)
            )
          )
        end
      end
    end

    context "with parent" do
      it "should enqueue sidekiq jobs" do
        parent = create(:organization, gr_id: "xyz")
        organization = create(:organization, parent: parent, gr_id: "abc")
        clear_sidekiq_jobs_and_locks
        expect do
          organization.destroy
        end.to change(GlobalRegistry::Bindings::Workers::PushEntityWorker.jobs, :size).by(0).and(
          change(GlobalRegistry::Bindings::Workers::PushRelationshipWorker.jobs, :size).by(0).and(
            change(GlobalRegistry::Bindings::Workers::DeleteEntityWorker.jobs, :size).by(1)
          )
        )
      end

      context "with area" do
        it "should enqueue sidekiq jobs" do
          area = create(:area, global_registry_id: "efg")
          parent = create(:organization, gr_id: "xyz")
          organization = create(:organization, area: area, gr_id: "abc", global_registry_area_id: "ijk", parent: parent)
          clear_sidekiq_jobs_and_locks
          expect do
            organization.destroy
          end.to change(GlobalRegistry::Bindings::Workers::PushEntityWorker.jobs, :size).by(0).and(
            change(GlobalRegistry::Bindings::Workers::PushRelationshipWorker.jobs, :size).by(0).and(
              change(GlobalRegistry::Bindings::Workers::DeleteEntityWorker.jobs, :size).by(2)
            )
          )
        end
      end
    end
  end
end
