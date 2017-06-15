# frozen_string_literal: true

require 'sidekiq'
require 'sidekiq-unique-jobs'

module GlobalRegistry #:nodoc:
  module Bindings #:nodoc:
    module Workers #:nodoc:
      class PushRelationshipWorker
        include Sidekiq::Worker
        sidekiq_options unique: :until_and_while_executing

        def perform(model_class, id)
          klass = model_class.is_a?(String) ? model_class.constantize : model_class
          klass.find(id).send(:push_relationship_to_global_registry)
        rescue ActiveRecord::RecordNotFound # rubocop:disable Lint/HandleExceptions
          # If the record was deleted after the job was created, swallow it
        end
      end
    end
  end
end
