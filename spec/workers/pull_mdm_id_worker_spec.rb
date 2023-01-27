# frozen_string_literal: true

require "spec_helper"

RSpec.describe GlobalRegistry::Bindings::Workers::PullMdmIdWorker do
  context Namespaced::Person do
    let(:person) { create(:person) }

    context "with valid id" do
      it "should call #pull_mdm_id_from_global_registry" do
        expect(Namespaced::Person).to receive(:find).with(person.id).and_return(person)

        worker_name =
          "GlobalRegistry::Bindings::Workers::#{Namespaced::Person.global_registry_entity.mdm_worker_class_name}"
        worker = worker_name.constantize.new
        expect(worker).to receive(:pull_mdm_id_from_global_registry)
        worker.perform("Namespaced::Person", person.id)
        expect(worker.model).to be person
      end
    end

    context ActiveRecord::RecordNotFound do
      it "should fail silently" do
        expect(Namespaced::Person).to receive(:find).with(person.id).and_raise(ActiveRecord::RecordNotFound)
        expect(GlobalRegistry::Bindings::Workers::PullMdmIdWorker).not_to receive(:pull_mdm_id_from_global_registry)

        worker_name =
          "GlobalRegistry::Bindings::Workers::#{Namespaced::Person.global_registry_entity.mdm_worker_class_name}"
        worker = worker_name.constantize.new
        worker.perform(Namespaced::Person, person.id)
        expect(worker.model).to be nil
      end
    end

    context RestClient::ResourceNotFound do
      it "should log a message" do
        expect(Namespaced::Person).to receive(:find).with(person.id).and_raise(RestClient::ResourceNotFound)
        expect(GlobalRegistry::Bindings::Workers::PullMdmIdWorker).not_to receive(:pull_mdm_id_from_global_registry)
        expect(Rails.logger).to receive(:info).with("GR entity for GlobalRegistry::Bindings::Workers::PullNamespaced" \
                                                    "PersonMdmIdWorker 1 does not exist; will _not_ retry")

        worker_name =
          "GlobalRegistry::Bindings::Workers::#{Namespaced::Person.global_registry_entity.mdm_worker_class_name}"
        worker = worker_name.constantize.new
        worker.perform(Namespaced::Person, person.id)
        expect(worker.model).to be nil
      end
    end
  end

  describe "#pull_mdm_id_from_global_registry" do
    context Namespaced::Person do
      let(:worker) { GlobalRegistry::Bindings::Workers::PullNamespacedPersonMdmIdWorker.new }
      before do
        worker.model = person
      end

      context "model missing global_registry_id" do
        let(:person) { create(:person) }

        it "should raise an exception" do
          expect do
            worker.pull_mdm_id_from_global_registry
          end.to raise_error GlobalRegistry::Bindings::RecordMissingGlobalRegistryId,
            "Namespaced::Person(#{person.id}) has no global_registry_id; will retry"
        end
      end

      context "entity missing mdm id" do
        let(:person) { create(:person, global_registry_id: "22527d88-3cba-11e7-b876-129bd0521531") }
        let!(:request) do
          stub_request(:get, "https://backend.global-registry.org/entities/22527d88-3cba-11e7-b876-129bd0521531")
            .with(query: {"filters[owned_by]" => "mdm"})
            .to_return(body: file_fixture("get_entities_person.json"), status: 200)
        end

        it "should raise an exception" do
          expect do
            worker.pull_mdm_id_from_global_registry
          end.to raise_error GlobalRegistry::Bindings::EntityMissingMdmId,
            "GR entity #{person.global_registry_id} for Namespaced::Person(#{person.id}) has " \
            "no mdm id; will retry"
        end
      end

      context "entity missing mdm id" do
        let(:person) { create(:person, global_registry_id: "22527d88-3cba-11e7-b876-129bd0521531") }
        let!(:request) do
          stub_request(:get, "https://backend.global-registry.org/entities/22527d88-3cba-11e7-b876-129bd0521531")
            .with(query: {"filters[owned_by]" => "mdm"})
            .to_return(body: file_fixture("get_entities_person_mdm.json"), status: 200)
        end

        it "should raise an exception" do
          expect do
            worker.pull_mdm_id_from_global_registry
            expect(person.global_registry_mdm_id).to eq "c81340b2-7e57-4978-b6b9-396f21bb0bb2"
          end.not_to raise_error
        end
      end
    end
  end

  describe "#mdm_worker_class" do
    before do
      module MdmTest
        class Klass
          def self.global_registry_entity
            @gr ||= Object.new
          end
        end
      end
    end
    after do
      MdmTest.send :remove_const, :Klass
      GlobalRegistry::Bindings::Workers.send :remove_const, :PullMdmTestKlassMdmIdWorker
    end

    it "generates worker class with mdm timeout set" do
      expect(MdmTest::Klass.global_registry_entity).to(
        receive(:mdm_worker_class_name).and_return("PullMdmTestKlassMdmIdWorker")
      )
      expect(MdmTest::Klass.global_registry_entity).to(
        receive(:mdm_timeout).and_return(33.minutes)
      )

      GlobalRegistry::Bindings::Workers.mdm_worker_class(MdmTest::Klass)
      expect(GlobalRegistry::Bindings::Workers.const_defined?(:PullMdmTestKlassMdmIdWorker)).to be true
      expect(GlobalRegistry::Bindings::Workers::PullMdmTestKlassMdmIdWorker.get_sidekiq_options)
        .to include("unique" => :until_timeout, "unique_expiration" => 33.minutes)
    end
  end
end
