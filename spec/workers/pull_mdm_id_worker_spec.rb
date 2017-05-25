# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'GlobalRegistry::Bindings::Workers' do
  describe 'PullMdmIdWorker' do
    let(:user) { create(:person) }

    it 'sends :pull_mdm_id_from_global_registry to the model instance' do
      allow(Namespaced::Person).to receive(:pull_mdm_id_from_global_registry)
      expect(Namespaced::Person).to receive(:find).with(user.id).and_return(user)
      expect(user).to receive(:pull_mdm_id_from_global_registry)

      worker_name = "GlobalRegistry::Bindings::Workers::#{Namespaced::Person.global_registry.mdm_worker_class_name}"
      worker = worker_name.constantize.new
      worker.perform(Namespaced::Person, user.id)
    end

    it 'fails silently on ActiveRecord::RecordNotFound' do
      allow(Namespaced::Person).to receive(:pull_mdm_id_from_global_registry)
      expect(Namespaced::Person).to receive(:find).with(user.id).and_raise(ActiveRecord::RecordNotFound)
      expect(user).not_to receive(:pull_mdm_id_from_global_registry)

      worker_name = "GlobalRegistry::Bindings::Workers::#{Namespaced::Person.global_registry.mdm_worker_class_name}"
      worker = worker_name.constantize.new
      worker.perform(Namespaced::Person, user.id)
    end

    it 'logs a message on RestClient::ResourceNotFound' do
      allow(Namespaced::Person).to receive(:pull_mdm_id_from_global_registry)
      expect(Namespaced::Person).to receive(:find).with(user.id).and_raise(RestClient::ResourceNotFound)
      expect(user).not_to receive(:pull_mdm_id_from_global_registry)
      expect(Rails.logger).to receive(:info).with('GR entity for GlobalRegistry::Bindings::Workers::PullNamespaced' \
                                                  'PersonMdmIdWorker 1 does not exist; will _not_ retry')

      worker_name = "GlobalRegistry::Bindings::Workers::#{Namespaced::Person.global_registry.mdm_worker_class_name}"
      worker = worker_name.constantize.new
      worker.perform(Namespaced::Person, user.id)
    end
  end

  describe 'mdm_worker_class' do
    before do
      module MdmTest
        class Klass
          def self.global_registry
            @gr ||= Object.new
          end
        end
      end
    end
    after do
      MdmTest.send :remove_const, :Klass
      GlobalRegistry::Bindings::Workers.send :remove_const, :PullMdmTestKlassMdmIdWorker
    end

    it 'generates worker class with mdm timeout set' do
      expect(MdmTest::Klass.global_registry).to(
        receive(:mdm_worker_class_name).and_return('PullMdmTestKlassMdmIdWorker')
      )
      expect(MdmTest::Klass.global_registry).to(
        receive(:mdm_timeout).and_return(33.minutes)
      )

      GlobalRegistry::Bindings::Workers.mdm_worker_class(MdmTest::Klass)
      expect(GlobalRegistry::Bindings::Workers.const_defined?(:PullMdmTestKlassMdmIdWorker)).to be true
      expect(GlobalRegistry::Bindings::Workers::PullMdmTestKlassMdmIdWorker.get_sidekiq_options)
        .to include('unique' => :until_timeout, 'unique_expiration' => 33.minutes)
    end
  end
end
