# frozen_string_literal: true

require "spec_helper"

RSpec.describe Namespaced::Person::UserEdited do
  describe "#pull_mdm_id_from_global_registry_async" do
    it "should enqueue sidekiq job" do
      user_edited = build(:user_edited)
      expect do
        user_edited.pull_mdm_id_from_global_registry_async
      end.to change(GlobalRegistry::Bindings::Workers::PullNamespacedPersonMdmIdWorker.jobs, :size).by(1)
    end
  end
end
