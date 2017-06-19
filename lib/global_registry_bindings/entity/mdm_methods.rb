# frozen_string_literal: true

require 'global_registry_bindings/workers/pull_mdm_id_worker'

module GlobalRegistry #:nodoc:
  module Bindings #:nodoc:
    module Entity #:nodoc:
      module MdmMethods
        extend ActiveSupport::Concern

        included do
          GlobalRegistry::Bindings::Workers.mdm_worker_class(self)
          after_commit :pull_mdm_id_from_global_registry_async, on: %i[create update]
        end

        def pull_mdm_id_from_global_registry_async
          "::GlobalRegistry::Bindings::Workers::#{global_registry.mdm_worker_class_name}".constantize
                                                                                         .perform_async(self.class, id)
        end

        def pull_mdm_id_from_global_registry # rubocop:disable Metrics/AbcSize
          unless global_registry.id_value?
            # Record missing Global Registry ID, enqueue it to be pushed.
            push_entity_to_global_registry_async
            raise GlobalRegistry::Bindings::RecordMissingGlobalRegistryId,
                  "#{self.class.name} #{id} has no #{global_registry.id_column}; will retry"
          end
          entity = GlobalRegistry::Entity.find(global_registry.id_value, 'filters[owned_by]' => 'mdm')
          mdm_entity_id = dig_global_registry_mdm_id_from_entity(entity, global_registry.type.to_s)
          unless mdm_entity_id
            raise GlobalRegistry::Bindings::EntityMissingMdmId,
                  "GR entity #{global_registry.id_value} for #{self.class.name} #{id} has no mdm id; will retry"
          end
          update_column(global_registry.mdm_id_column, mdm_entity_id) # rubocop:disable Rails/SkipsModelValidations
        end

        def dig_global_registry_mdm_id_from_entity(entity, type)
          Array.wrap(entity.dig('entity', type, "master_#{type}:relationship"))
               .first # although there should not be more than one
               .try(:[], "master_#{type}")
        end
      end
    end
  end
end
