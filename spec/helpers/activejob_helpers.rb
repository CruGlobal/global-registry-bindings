
module WithQueueDefinition
  extend ActiveSupport::Concern

  included do
    before do
      GlobalRegistry::Bindings.configure do |config|
        config.activejob_options = { queue: :default }
      end
    end
    after do
      GlobalRegistry::Bindings.configure do |config|
        config.activejob_options = {}
      end
    end
  end
end