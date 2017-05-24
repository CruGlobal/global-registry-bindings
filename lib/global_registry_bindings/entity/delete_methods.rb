# frozen_string_literal: true

require 'global_registry_bindings/workers/delete_gr_entity_worker'

module GlobalRegistry #:nodoc:
  module Bindings #:nodoc:
    module Entity #:nodoc:
      module DeleteMethods
        extend ActiveSupport::Concern

        included do
          after_commit :delete_from_global_registry_async, on: :destroy
        end

        def delete_from_global_registry_async
          return unless global_registry.id_value?
          ::GlobalRegistry::Bindings::Workers::DeleteGrEntityWorker.perform_async(global_registry.id_value)
        end
      end
    end
  end
end
