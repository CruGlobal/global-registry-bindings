# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'GlobalRegistry::Bindings' do

  describe 'configure' do

    it 'should have default activejob_options' do
      expect(GlobalRegistry::Bindings.activejob_options).to be_a(Hash).and be_empty
    end

    it 'should have default sqs_error_action' do
      expect(GlobalRegistry::Bindings.sqs_error_action).to be :log
    end

    context 'custom GlobalRegistry::Bindings config' do
      after(:each) do
        GlobalRegistry::Bindings.configure do |config|
          config.activejob_options = {}
          config.queues = {}
          config.sqs_error_action = nil
        end
      end

      context 'sqs_error_action' do
        it 'schould contain :ignore' do
          GlobalRegistry::Bindings.configure do |config|
            config.sqs_error_action = :ignore
          end
          expect(GlobalRegistry::Bindings.sqs_error_action).to eq(:ignore)
        end

        it 'schould contain :raise' do
          GlobalRegistry::Bindings.configure do |config|
            config.sqs_error_action = :raise
          end
          expect(GlobalRegistry::Bindings.sqs_error_action).to eq(:raise)
        end

        it 'schould contain :log' do
          GlobalRegistry::Bindings.configure do |config|
            config.sqs_error_action = :log
          end
          expect(GlobalRegistry::Bindings.sqs_error_action).to eq(:log)
        end

        it 'schould retreat to :log when the value is unknown' do
          GlobalRegistry::Bindings.configure do |config|
            config.sqs_error_action = :something
          end
          expect(GlobalRegistry::Bindings.sqs_error_action).to eq(:log)
        end
      end

      context 'activejob_options' do
        it 'should contain custom activejob options' do
          opts = {queue: :default, wait: 5.seconds}

          GlobalRegistry::Bindings.configure do |config|
            config.activejob_options = opts
          end

          expect(GlobalRegistry::Bindings.activejob_options).to eq(opts)
        end
      end

      context 'queues' do
        it 'should contain custom, default queue definition when provided name' do
          queue_name = SecureRandom.uuid

          GlobalRegistry::Bindings.configure do |config|
            config.queues = queue_name
          end

          expect(GlobalRegistry::Bindings.queues).to eq({default: queue_name})
        end

        it 'should contain custom map of queues' do
          queue_map = {
              default: SecureRandom.uuid,
              unique:  SecureRandom.uuid
          }

          GlobalRegistry::Bindings.configure do |config|
            config.queues = queue_map
          end

          expect(GlobalRegistry::Bindings.queues).to eq(queue_map)
        end

        it 'should throw exception when the type of queue definition is invalid' do
          queue_map = 42

          expect{
            GlobalRegistry::Bindings.configure do |config|
              config.queues = queue_map
            end
          }.to raise_error(ArgumentError)
        end
      end

      context 'resolve_queue_name' do
        it 'should resolve to a default when a name was not provided' do
          queue_name = SecureRandom.uuid

          GlobalRegistry::Bindings.configure do |config|
            config.queues = queue_name
          end

          expect(GlobalRegistry::Bindings.resolve_queue_name(nil)).to eq(queue_name)
        end

        it 'should resolve to a default from hash when name was not provided' do
          default_queue_name = SecureRandom.uuid
          queue_map = {
              default: default_queue_name,
              other_queue: SecureRandom.uuid
          }

          GlobalRegistry::Bindings.configure do |config|
            config.queues = queue_map
          end

          expect(GlobalRegistry::Bindings.resolve_queue_name(nil)).to eq(default_queue_name)
        end

        it 'should throw an error when a name was not provided and there is no default in queue map' do
          queue_map = {
              some_queue: SecureRandom.uuid,
              other_queue: SecureRandom.uuid
          }

          GlobalRegistry::Bindings.configure do |config|
            config.queues = queue_map
          end

          expect{
            GlobalRegistry::Bindings.resolve_queue_name(nil)
          }.to raise_error(ArgumentError)
        end

        it 'should resolve to a given name when it is a String' do
          queue_name = SecureRandom.uuid

          GlobalRegistry::Bindings.configure do |config|
            config.queues = queue_name
          end

          specific_queue_name = SecureRandom.uuid
          expect(GlobalRegistry::Bindings.resolve_queue_name(specific_queue_name)).to eq(specific_queue_name)
        end

        it 'should resolve to a name from a map when it is a symbol' do
          queue_name = SecureRandom.uuid
          queue_map = {
              queue_1: SecureRandom.uuid,
              queue_2: queue_name,
              default: SecureRandom.uuid
          }

          GlobalRegistry::Bindings.configure do |config|
            config.queues = queue_map
          end

          expect(GlobalRegistry::Bindings.resolve_queue_name(:queue_2)).to eq(queue_name)
        end

        it 'should throw an exception if the name is a symbol and queues map are defined' do
          queue_map = {
              queue_1: SecureRandom.uuid,
              default: SecureRandom.uuid
          }

          GlobalRegistry::Bindings.configure do |config|
            config.queues = queue_map
          end

          expect{
            GlobalRegistry::Bindings.resolve_queue_name(:queue_2)
          }.to raise_error(ArgumentError)
        end

        it 'should use the symbol if the name is a symbol and queue config is empty' do
          expect(GlobalRegistry::Bindings.resolve_queue_name(:queue_2)).to eq(:queue_2)
        end
      end

      context 'resolve_activejob_options' do

        it 'resolves to default options when options not provided' do
          default_aj_options = {queue: 'abc', wait: 4.seconds}
          GlobalRegistry::Bindings.configure do |config|
            config.activejob_options = default_aj_options
          end

          expect(GlobalRegistry::Bindings.resolve_activejob_options(nil)).
              to eq(default_aj_options)
        end

        it 'resolves missing options to default' do
          default_aj_options = {wait: 4.seconds}
          GlobalRegistry::Bindings.configure do |config|
            config.activejob_options = default_aj_options
          end

          queue_name = SecureRandom.uuid
          expect(GlobalRegistry::Bindings.resolve_activejob_options({queue: queue_name})).
              to eq({wait: 4.seconds, queue: queue_name})
        end

        it 'clears the option when the option value is nil' do
          default_aj_options = {queue: SecureRandom.uuid, wait: 4.seconds}
          GlobalRegistry::Bindings.configure do |config|
            config.activejob_options = default_aj_options
          end

          queue_name = SecureRandom.uuid
          expect(GlobalRegistry::Bindings.resolve_activejob_options({queue: queue_name, wait: nil})).
              to eq({queue: queue_name})
        end

        it 'clears the option when the option value is nil, with queue config' do
          default_aj_options = {queue: SecureRandom.uuid, wait: 4.seconds}
          queue_1_name = SecureRandom.uuid
          queue_map = {
              queue_1: queue_1_name,
              default: SecureRandom.uuid
          }
          GlobalRegistry::Bindings.configure do |config|
            config.activejob_options = default_aj_options
            config.queues = queue_map
          end

          expect(GlobalRegistry::Bindings.resolve_activejob_options({queue: :queue_1, wait: nil})).
              to eq({queue: queue_1_name})
        end

        it 'uses just provided queue name when there are no default options' do
          queue_name = SecureRandom.uuid
          expect(GlobalRegistry::Bindings.resolve_activejob_options({queue: queue_name})).
              to eq({queue: queue_name})
        end

        it 'uses default queue name when there are no default activejob options' do
          default_queue = SecureRandom.uuid
          queue_map = {
              queue_1: SecureRandom.uuid,
              default: default_queue
          }
          GlobalRegistry::Bindings.configure do |config|
            config.queues = queue_map
          end

          expect(GlobalRegistry::Bindings.resolve_activejob_options(nil)).
              to eq({queue: default_queue})
        end
      end
    end
  end
end
