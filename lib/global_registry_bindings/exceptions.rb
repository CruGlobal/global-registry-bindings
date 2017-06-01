# frozen_string_literal: true

module GlobalRegistry #:nodoc:
  module Bindings #:nodoc:
    class RecordMissingGlobalRegistryId < StandardError; end
    class EntityMissingMdmId < StandardError; end
    class RelatedEntityMissingGlobalRegistryId < StandardError; end
  end
end
