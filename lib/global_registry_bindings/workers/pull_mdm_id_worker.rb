# frozen_string_literal: true

require 'global_registry_bindings/entity/mdm_methods'

module GlobalRegistry #:nodoc:
  module Bindings #:nodoc:
    module Workers #:nodoc:
      def self.mdm_worker_class(model_class)
        klass = Class.new(PullMdmIdWorker) do
          sidekiq_options unique: :until_timeout, unique_expiration: model_class.global_registry.mdm_timeout
        end
        const_set model_class.global_registry.mdm_worker_class_name, klass
      end

      class PullMdmIdWorker < ::GlobalRegistry::Bindings::Worker
        include GlobalRegistry::Bindings::Entity::MdmMethods

        def perform(model_class, id)
          super model_class, id
          pull_mdm_id_from_global_registry
        rescue ActiveRecord::RecordNotFound
          # If the record was deleted after the job was created, swallow it
          return
        rescue RestClient::ResourceNotFound
          Rails.logger.info "GR entity for #{self.class.name} #{id} does not exist; will _not_ retry"
        end
      end
    end
  end
end
