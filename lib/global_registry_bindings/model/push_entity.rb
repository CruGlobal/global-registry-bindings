# frozen_string_literal: true

require 'global_registry_bindings/workers/push_entity_worker'

module GlobalRegistry #:nodoc:
  module Bindings #:nodoc:
    module Model #:nodoc:
      module PushEntity
        extend ActiveSupport::Concern

        included do
          after_commit :push_entity_to_global_registry_async, on: (global_registry_entity.push_on - %i[delete])
        end

        def push_entity_to_global_registry_async
          ::GlobalRegistry::Bindings::Workers::PushEntityWorker.perform_async(self.class, id)
        end
      end
    end
  end
end