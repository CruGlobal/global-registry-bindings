# frozen_string_literal: true

module GlobalRegistry #:nodoc:
  module Bindings #:nodoc:
    class Testing
      class << self
        attr_accessor :__test_mode

        def __set_test_mode(mode)
          if block_given?
            current_mode = __test_mode
            begin
              self.__test_mode = mode
              yield
            ensure
              self.__test_mode = current_mode
            end
          else
            self.__test_mode = mode
          end
        end

        def skip_workers!(&block)
          __set_test_mode(:skip, &block)
        end

        def disable_test_helper!(&block)
          __set_test_mode(:disable, &block)
        end

        def enabled?
          __test_mode != :disable
        end

        def disabled?
          __test_mode == :disable
        end

        def skip?
          __test_mode == :skip
        end
      end
    end

    class Worker
      class << self
        alias perform_async_real perform_async

        def perform_async(*args)
          return if GlobalRegistry::Bindings::Testing.skip?
          perform_async_real(*args)
        end
      end
    end
  end
end

# Default to disabling testing helpers
GlobalRegistry::Bindings::Testing.disable_test_helper!
