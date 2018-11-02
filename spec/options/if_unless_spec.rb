# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Options' do
  before do
    stub_const 'Foo', Class.new(::ApplicationRecord)
  end

  describe 'entity' do
    describe ':if' do
      context 'value as proc' do
        before do
          Foo.class_eval { global_registry_bindings type: :foo, if: proc { |_model| true } }
        end

        it 'should not enqueue ActiveJob job' do
          foo = Foo.new
          expect do
            foo.save
          end.to have_enqueued_job(GlobalRegistry::Bindings::Workers::PushEntityWorker).exactly(0)
        end
      end

      context 'value as symbol' do
        before do
          Foo.class_eval { global_registry_bindings type: :foo, if: :if_cond }
          Foo.class_eval do
            def if_cond(_model)
              true
            end
          end
        end

        it 'should not enqueue ActiveJob job' do
          foo = Foo.new
          expect do
            foo.save
          end.to have_enqueued_job(GlobalRegistry::Bindings::Workers::PushEntityWorker).exactly(0)
        end
      end
    end

    describe ':unless' do
      context 'value as proc' do
        before do
          Foo.class_eval { global_registry_bindings type: :foo, unless: proc { |_model| false } }
        end

        it 'should not enqueue ActiveJob job' do
          foo = Foo.new
          expect do
            foo.save
          end.to have_enqueued_job(GlobalRegistry::Bindings::Workers::PushEntityWorker).exactly(0)
        end
      end

      context 'value as symbol' do
        before do
          Foo.class_eval { global_registry_bindings type: :foo, unless: :unless_cond }
          Foo.class_eval do
            def unless_cond(_model)
              false
            end
          end
        end

        it 'should not enqueue ActiveJob job' do
          foo = Foo.new
          expect do
            foo.save
          end.to have_enqueued_job(GlobalRegistry::Bindings::Workers::PushEntityWorker).exactly(0)
        end
      end
    end
  end

  describe 'relationship' do
    describe ':if' do
      context 'value as proc' do
        before do
          Foo.class_eval { global_registry_bindings binding: :relationship, type: :foo, if: proc { |_model| true } }
        end

        it 'should not enqueue ActiveJob job' do
          foo = Foo.new
          expect do
            foo.save
          end.to have_enqueued_job(GlobalRegistry::Bindings::Workers::PushEntityWorker).exactly(0)
        end
      end

      context 'value as symbol' do
        before do
          Foo.class_eval { global_registry_bindings binding: :relationship, type: :foo, if: :if_cond }
          Foo.class_eval do
            def if_cond(_type, _model)
              true
            end
          end
        end

        it 'should not enqueue ActiveJob job' do
          foo = Foo.new
          expect do
            foo.save
          end.to have_enqueued_job(GlobalRegistry::Bindings::Workers::PushRelationshipWorker).exactly(0)
        end
      end
    end

    describe ':unless' do
      context 'value as proc' do
        before do
          Foo.class_eval do
            global_registry_bindings binding: :relationship, type: :foo, unless: proc { |_model| false }
          end
        end

        it 'should not enqueue ActiveJob job' do
          foo = Foo.new
          expect do
            foo.save
          end.to have_enqueued_job(GlobalRegistry::Bindings::Workers::PushRelationshipWorker).exactly(0)
        end
      end

      context 'value as symbol' do
        before do
          Foo.class_eval { global_registry_bindings binding: :relationship, type: :foo, unless: :unless_cond }
          Foo.class_eval do
            def unless_cond(_type, _model)
              false
            end
          end
        end

        it 'should not enqueue ActiveJob job' do
          foo = Foo.new
          expect do
            foo.save
          end.to have_enqueued_job(GlobalRegistry::Bindings::Workers::PushRelationshipWorker).exactly(0)
        end
      end
    end
  end
end
