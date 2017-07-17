# frozen_string_literal: true

module SidekiqHelpers
  def clear_sidekiq_jobs_and_locks
    # Drop sidekiq-unique-jobs locks
    MOCK_REDIS.keys.each do |key|
      MOCK_REDIS.del(key)
    end

    # Clear sidekiq queues and workers
    Sidekiq::Queues.clear_all
    Sidekiq::Worker.clear_all
  end
end
