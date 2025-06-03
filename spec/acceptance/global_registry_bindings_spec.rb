# frozen_string_literal: true

require "spec_helper"

RSpec.describe "GlobalRegistry::Bindings" do
  describe "ActiveRecord::Base extensions" do
    it "should respond to global_registry_bindings" do
      expect(::ActiveRecord::Base).to respond_to :global_registry_bindings
    end
  end

  describe "Options" do
    it "should have default values for all options" do
      expect(Default.global_registry_entity.id_column).to be :global_registry_id
      expect(Default.global_registry_entity.mdm_id_column).to be nil
      expect(Default.global_registry_entity.parent).to be nil
      expect(Default.global_registry_entity.push_on)
        .to contain_exactly(:create, :update, :destroy)
      expect(Default.global_registry_entity.mdm_timeout).to eq 1.minute
      expect(Default.global_registry_entity.type).to be :default
      expect(Default.global_registry_entity.exclude)
        .to contain_exactly(:global_registry_id, :id, :created_at, :updated_at)
      expect(Default.global_registry_entity.fields).to be_a(Hash).and be_empty
    end

    it "should parse and set mdm options" do
      expect(Namespaced::Person.global_registry_entity.id_column).to be :global_registry_id
      expect(Namespaced::Person.global_registry_entity.mdm_id_column).to be :global_registry_mdm_id
      expect(Namespaced::Person.global_registry_entity.mdm_timeout).to eq 24.hours
      expect(Namespaced::Person.global_registry_entity.type).to be :person
      expect(Namespaced::Person.global_registry_entity.exclude)
        .to contain_exactly(:country_of_residence_gr_id, :country_of_residence_id, :country_of_service_gr_id,
          :country_of_service_id, :created_at, :global_registry_id, :global_registry_mdm_id,
          :guid, :id, :updated_at, :global_registry_fingerprint)
      expect(Namespaced::Person.global_registry_entity.fields).to be_a(Hash).and be_empty
      expect(GlobalRegistry::Bindings::Workers::PullNamespacedPersonMdmIdWorker.get_sidekiq_options)
        .to include("unique" => :until_timeout, "unique_expiration" => 24.hours)
    end

    it "should parse and set exclude and extra fields options" do
      address = build(:address)
      expect(Address.global_registry_entity.id_column).to be :global_registry_id
      expect(Address.global_registry_entity.mdm_id_column).to be nil
      expect(Address.global_registry_entity.type).to be :address
      expect(Address.global_registry_entity.parent).to be :person
      expect(Address.global_registry_entity.exclude).to be_a Proc
      expect(address.global_registry_entity.exclude)
        .to contain_exactly(:global_registry_id, :id, :created_at, :updated_at, :person_id, :address1)
      expect(Address.global_registry_entity.fields).to be_a Symbol
      expect(address.global_registry_entity.fields)
        .to include(line1: :string, postal_code: :string)
    end

    it "should parse and set push_on fields" do
      org = build(:organization)
      expect(Organization.global_registry_entity.id_column).to be :gr_id
      expect(Organization.global_registry_entity.mdm_id_column).to be nil
      expect(Organization.global_registry_entity.type).to be_a Proc
      expect(org.global_registry_entity.type).to be :fancy_org
      expect(Organization.global_registry_entity.parent).to be :parent
      expect(Organization.global_registry_entity.push_on).to be_an(Array).and eq(%i[create destroy])
      expect(Organization.global_registry_entity.exclude).to be_a Symbol
      expect(org.global_registry_entity.exclude)
        .to contain_exactly(:gr_id, :id, :created_at, :updated_at, :parent_id, :area_id, :global_registry_area_id)
      expect(Organization.global_registry_entity.fields).to be_a Proc
      expect(org.global_registry_entity.fields).to be_a(Hash).and be_empty
    end

    it "should parse and set relationship fields" do
      person = build(:person)
      org = build(:organization)
      assignment = build(:assignment, person: person, organization: org)
      expect(Assignment.global_registry_relationship(:fancy_org_assignment).id_column).to be :global_registry_id
      expect(Assignment.global_registry_relationship(:fancy_org_assignment).type).to be :fancy_org_assignment
      expect(Assignment.global_registry_relationship(:fancy_org_assignment).primary).to be :person
      expect(Assignment.global_registry_relationship(:fancy_org_assignment).related).to be :organization
      expect(assignment.global_registry_relationship(:fancy_org_assignment).primary_name).to be :person
      expect(assignment.global_registry_relationship(:fancy_org_assignment).related_name).to be :fancy_org
      expect(assignment.global_registry_relationship(:fancy_org_assignment).exclude)
        .to contain_exactly(:global_registry_id, :id, :created_at, :updated_at, :person_id, :organization_id,
          :assigned_by_gr_rel_id, :assigned_by_id)
      expect(assignment.global_registry_relationship(:fancy_org_assignment).fields)
        .to be_a(Hash)
    end
  end

  describe "configure" do
    it "should have default sidekiq_options" do
      expect(GlobalRegistry::Bindings.sidekiq_options).to be_a(Hash).and be_empty
    end

    it "should have default redis_error_action" do
      expect(GlobalRegistry::Bindings.redis_error_action).to be :log
    end

    context "custom sidekiq queue" do
      before do
        GlobalRegistry::Bindings.configure do |config|
          config.sidekiq_options = {queue: :custom}
        end
      end
      after do
        GlobalRegistry::Bindings.configure do |config|
          config.sidekiq_options = {}
        end
      end
      let(:job) do
        GlobalRegistry::Bindings::Workers::DeleteEntityWorker.perform_async(123)
        GlobalRegistry::Bindings::Workers::DeleteEntityWorker.jobs.last
      end

      it "should contain global custom queue" do
        expect(GlobalRegistry::Bindings.sidekiq_options).to be_a(Hash).and(include(queue: :custom))
        expect(job).to include("queue" => "custom")
      end
    end

    describe "redis_error_action" do
      around do |example|
        RSpec::Mocks.with_temporary_scope do
          stub_const("Rollbar", Class.new)
          example.run
        end
      end

      context ":ignore" do
        around do |example|
          GlobalRegistry::Bindings.configure do |config|
            config.redis_error_action = :ignore
          end
          example.run
          GlobalRegistry::Bindings.configure do |config|
            config.redis_error_action = :log
          end
        end

        it "should silently ignore redis errors" do
          allow(Rollbar).to receive(:error)
          expect(GlobalRegistry::Bindings::Worker).to receive(:set).and_raise(RedisClient::Error)
          expect do
            GlobalRegistry::Bindings::Worker.perform_async
          end.to_not raise_error
          expect(GlobalRegistry::Bindings::Worker.jobs.size).to be 0
          expect(Rollbar).not_to have_received(:error)
        end
      end

      context ":log" do
        around do |example|
          GlobalRegistry::Bindings.configure do |config|
            config.redis_error_action = :log
          end
          example.run
          GlobalRegistry::Bindings.configure do |config|
            config.redis_error_action = :log
          end
        end

        it "should log redis errors" do
          allow(Rollbar).to receive(:error)
          expect(GlobalRegistry::Bindings::Worker).to receive(:set).and_raise(RedisClient::Error)
          expect do
            GlobalRegistry::Bindings::Worker.perform_async
          end.to_not raise_error
          expect(GlobalRegistry::Bindings::Worker.jobs.size).to be 0
          expect(Rollbar).to have_received(:error)
        end
      end

      context ":raise" do
        around do |example|
          GlobalRegistry::Bindings.configure do |config|
            config.redis_error_action = :raise
          end
          example.run
          GlobalRegistry::Bindings.configure do |config|
            config.redis_error_action = :log
          end
        end

        it "should re-raise redis errors" do
          allow(Rollbar).to receive(:error)
          expect(GlobalRegistry::Bindings::Worker).to receive(:set).and_raise(RedisClient::Error)
          expect do
            GlobalRegistry::Bindings::Worker.perform_async
          end.to raise_error(RedisClient::Error)
          expect(GlobalRegistry::Bindings::Worker.jobs.size).to be 0
        end
      end
    end
  end
end
