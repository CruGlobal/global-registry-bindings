# frozen_string_literal: true

module GlobalRegistry # :nodoc:
  module Bindings # :nodoc:
    module Entity # :nodoc:
      module MdmMethods
        extend ActiveSupport::Concern

        def pull_mdm_id_from_global_registry # rubocop:disable Metrics/AbcSize
          unless global_registry_entity.id_value?
            # Record missing Global Registry ID, enqueue it to be pushed.
            model.push_entity_to_global_registry_async
            raise GlobalRegistry::Bindings::RecordMissingGlobalRegistryId,
              "#{model.class.name}(#{model.id}) has no #{global_registry_entity.id_column}; will retry"
          end
          entity = GlobalRegistry::Entity.find(global_registry_entity.id_value, "filters[owned_by]" => "mdm")
          mdm_entity_id = dig_global_registry_mdm_id_from_entity(entity, global_registry_entity.type.to_s)
          unless mdm_entity_id
            raise GlobalRegistry::Bindings::EntityMissingMdmId,
              "GR entity #{global_registry_entity.id_value} for #{model.class.name}(#{model.id}) has no mdm id; " \
              "will retry"
          end
          # rubocop:disable Rails/SkipsModelValidations
          model.update_column(global_registry_entity.mdm_id_column, mdm_entity_id)
        end

        def dig_global_registry_mdm_id_from_entity(entity, type)
          Array.wrap(entity.dig("entity", type, "master_#{type}:relationship"))
            .first # although there should not be more than one
            .try(:[], "master_#{type}")
        end
      end
    end
  end
end
