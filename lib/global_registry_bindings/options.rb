# frozen_string_literal: true

require 'global_registry_bindings/options/instance_options'
require 'global_registry_bindings/options/class_options'

module GlobalRegistry #:nodoc:
  module Bindings #:nodoc:
    module Options
      extend ActiveSupport::Concern

      included do
        @_global_registry_bindings_class_options ||= GlobalRegistry::Bindings::Options::ClassOptions.new(self)
      end

      def global_registry
        @_global_registry_bindings_instance_options ||= GlobalRegistry::Bindings::Options::InstanceOptions.new(self)
      end

      module ClassMethods
        def global_registry
          @_global_registry_bindings_class_options
        end
      end
    end
  end
end
