# frozen_string_literal: true

module GlobalRegistry #:nodoc:
  module Bindings #:nodoc:
    class Railtie < Rails::Railtie
      initializer 'global_registry_bindings_railtie.configure_rollbar' do
        if Module.const_defined? :Rollbar
          ::Rollbar.configure do |config|
            config.exception_level_filters.merge!('GlobalRegistry::Bindings::RecordMissingGlobalRegistryId' => 'ignore',
                                                  'GlobalRegistry::Bindings::InvalidMasterPerson' => 'ignore')
          end
        end
      end
    end
  end
end
