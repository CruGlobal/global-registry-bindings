# frozen_string_literal: true

require 'global_registry_bindings/workers/push_entity_worker'

module GlobalRegistry #:nodoc:
  module Bindings #:nodoc:
    module Model #:nodoc:
      module PushEntity
        extend ActiveSupport::Concern

        included do
          after_commit :push_entity_to_global_registry_async, on: (global_registry_entity.push_on - %i[destroy])
        end

        def push_entity_to_global_registry_async
          return if global_registry_entity.condition?(:if)
          return unless global_registry_entity.condition?(:unless)
          job_options = global_registry_entity.job
          ::GlobalRegistry::Bindings::Workers::PushEntityWorker.perform_job(job_options, self.class.name, id)
        end
      end
    end
  end
end
