# frozen_string_literal: true

require "global_registry_bindings/workers/delete_entity_worker"

module GlobalRegistry # :nodoc:
  module Bindings # :nodoc:
    module Model # :nodoc:
      module DeleteEntity
        extend ActiveSupport::Concern

        included do
          after_commit :delete_entity_from_global_registry_async, on: :destroy
        end

        def delete_entity_from_global_registry_async
          return unless global_registry_entity.id_value?
          return if global_registry_entity.condition?(:if)
          return unless global_registry_entity.condition?(:unless)
          ::GlobalRegistry::Bindings::Workers::DeleteEntityWorker.perform_async(global_registry_entity.id_value)
        end
      end
    end
  end
end
