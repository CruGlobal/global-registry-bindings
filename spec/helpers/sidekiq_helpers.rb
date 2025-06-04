# frozen_string_literal: true

module SidekiqHelpers
  def clear_sidekiq_jobs_and_locks
    # Clear sidekiq queues and workers
    Sidekiq::Queues.clear_all
    Sidekiq::Worker.clear_all
  end
end
