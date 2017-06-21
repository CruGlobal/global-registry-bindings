# frozen_string_literal: true

module GlobalRegistry #:nodoc:
  module Bindings #:nodoc:
    module Workers #:nodoc:
      class DeleteEntityWorker < ::GlobalRegistry::Bindings::Worker
        sidekiq_options unique: :until_executed

        def perform(global_registry_id)
          GlobalRegistry::Entity.delete(global_registry_id)
        rescue RestClient::ResourceNotFound # rubocop:disable Lint/HandleExceptions
          # If the record doesn't exist, we don't care
        end
      end
    end
  end
end
