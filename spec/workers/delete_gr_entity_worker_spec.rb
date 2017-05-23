# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'GlobalRegistry::Bindings::Workers' do
  describe 'DeleteGrEntityWorker' do
    context 'valid global_registry_id' do
      let!(:request) do
        stub_request(:delete, 'https://backend.global-registry.org/entities/22527d88-3cba-11e7-b876-129bd0521531')
          .to_return(status: 200)
      end

      it 'should delete the entity' do
        worker = GlobalRegistry::Bindings::Workers::DeleteGrEntityWorker.new
        worker.perform('22527d88-3cba-11e7-b876-129bd0521531')
        expect(request).to have_been_requested.once
      end
    end

    context 'unknown global_registry_id' do
      let!(:request) do
        stub_request(:delete, 'https://backend.global-registry.org/entities/22527d88-3cba-11e7-b876-129bd0521531')
          .to_return(status: 404)
      end

      it 'should delete the entity' do
        worker = GlobalRegistry::Bindings::Workers::DeleteGrEntityWorker.new
        worker.perform('22527d88-3cba-11e7-b876-129bd0521531')
        expect(request).to have_been_requested.once
      end
    end
  end
end
