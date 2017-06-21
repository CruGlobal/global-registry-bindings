# frozen_string_literal: true

require 'global_registry_bindings/workers/pull_mdm_id_worker'

module GlobalRegistry #:nodoc:
  module Bindings #:nodoc:
    module Model #:nodoc:
      module PullMdm
        extend ActiveSupport::Concern

        included do
          GlobalRegistry::Bindings::Workers.mdm_worker_class(self)
          after_commit :pull_mdm_id_from_global_registry_async, on: %i[create update]
        end

        def pull_mdm_id_from_global_registry_async
          "::GlobalRegistry::Bindings::Workers::#{global_registry.mdm_worker_class_name}".constantize
                                                                                         .perform_async(self.class, id)
        end
      end
    end
  end
end
