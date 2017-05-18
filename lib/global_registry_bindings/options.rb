# frozen_string_literal: true

module GlobalRegistry #:nodoc:
  module Bindings #:nodoc:
    module Options
      extend ActiveSupport::Concern

      def global_registry_id_value
        send self.class.global_registry_bindings_options[:id_column]
      end

      def global_registry_id_value=(value)
        send self.class.global_registry_bindings_options[:id_column], value
      end

      module ClassMethods
        def entity_type_name
          global_registry_bindings_options[:type]
        end
      end
    end
  end
end
