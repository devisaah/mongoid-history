require 'spec_helper'

describe Mongoid::History::Trackable do
  describe 'SingletonMethods' do
    before :each do
      class MyTrackableModel
        include Mongoid::Document
        include Mongoid::History::Trackable

        field :foo
        field :b, as: :bar

        if Mongoid::Compatibility::Version.mongoid7_or_newer?
          embeds_one :my_embed_one_model
          embeds_one :my_untracked_embed_one_model
          embeds_many :my_embed_many_models
        else
          embeds_one :my_embed_one_model, inverse_class_name: 'MyEmbedOneModel'
          embeds_one :my_untracked_embed_one_model, inverse_class_name: 'MyUntrackedEmbedOneModel'
          embeds_many :my_embed_many_models, inverse_class_name: 'MyEmbedManyModel'
        end

        track_history on: %i[foo my_embed_one_model my_embed_many_models my_dynamic_field]
      end

      class MyEmbedOneModel
        include Mongoid::Document

        field :baz
        embedded_in :my_trackable_model
      end

      class MyUntrackedEmbedOneModel
        include Mongoid::Document

        field :baz
        embedded_in :my_trackable_model
      end

      class MyEmbedManyModel
        include Mongoid::Document

        field :bla
        embedded_in :my_trackable_model
      end
    end

    after :each do
      Object.send(:remove_const, :MyTrackableModel)
      Object.send(:remove_const, :MyEmbedOneModel)
      Object.send(:remove_const, :MyUntrackedEmbedOneModel)
      Object.send(:remove_const, :MyEmbedManyModel)
    end

    describe '#tracked?' do
      before { allow(MyTrackableModel).to receive(:dynamic_enabled?) { false } }
      it { expect(MyTrackableModel.tracked?(:foo)).to be true }
      it { expect(MyTrackableModel.tracked?(:bar)).to be false }
      it { expect(MyTrackableModel.tracked?(:my_embed_one_model)).to be true }
      it { expect(MyTrackableModel.tracked?(:my_untracked_embed_one_model)).to be false }
      it { expect(MyTrackableModel.tracked?(:my_embed_many_models)).to be true }
      it { expect(MyTrackableModel.tracked?(:my_dynamic_field)).to be true }
    end

    describe '#dynamic_field?' do
      before :each do
        class EmbOne
          include Mongoid::Document

          embedded_in :my_model
        end
      end

      after :each do
        Object.send(:remove_const, :EmbOne)
      end

      context 'when dynamic enabled' do
        context 'with embeds one relation' do
          before :each do
            class MyModel
              include Mongoid::Document
              include Mongoid::History::Trackable

              store_in collection: :my_models

              if Mongoid::Compatibility::Version.mongoid7_or_newer?
                embeds_one :emb_one
              else
                embeds_one :emb_one, inverse_class_name: 'EmbOne'
              end

              track_history
            end
          end

          after :each do
            Object.send(:remove_const, :MyModel)
          end

          it 'should track dynamic field' do
            allow(MyModel).to receive(:dynamic_enabled?) { true }
            expect(MyModel.dynamic_field?(:foo)).to be true
          end

          it 'should not track embeds_one relation' do
            allow(MyModel).to receive(:dynamic_enabled?) { true }
            expect(MyModel.dynamic_field?(:emb_one)).to be false
          end
        end

        context 'with embeds one relation and alias' do
          before :each do
            class MyModel
              include Mongoid::Document
              include Mongoid::History::Trackable

              store_in collection: :my_models

              if Mongoid::Compatibility::Version.mongoid7_or_newer?
                embeds_one :emb_one, store_as: :emo
              else
                embeds_one :emb_one, inverse_class_name: 'EmbOne', store_as: :emo
              end

              track_history
            end
          end

          after :each do
            Object.send(:remove_const, :MyModel)
          end

          it 'should not track embeds_one relation' do
            allow(MyModel).to receive(:dynamic_enabled?) { true }
            expect(MyModel.dynamic_field?(:emo)).to be false
          end
        end

        context 'with embeds many relation' do
          before :each do
            class MyModel
              include Mongoid::Document
              include Mongoid::History::Trackable

              store_in collection: :my_models

              if Mongoid::Compatibility::Version.mongoid7_or_newer?
                embeds_many :emb_ones
              else
                embeds_many :emb_ones, inverse_class_name: 'EmbOne'
              end

              track_history
            end
          end

          after :each do
            Object.send(:remove_const, :MyModel)
          end

          it 'should not track embeds_many relation' do
            allow(MyModel).to receive(:dynamic_enabled?) { true }
            expect(MyModel.dynamic_field?(:emb_ones)).to be false
          end
        end

        context 'with embeds many relation and alias' do
          before :each do
            class MyModel
              include Mongoid::Document
              include Mongoid::History::Trackable

              store_in collection: :my_models

              if Mongoid::Compatibility::Version.mongoid7_or_newer?
                embeds_many :emb_ones, store_as: :emos
              else
                embeds_many :emb_ones, store_as: :emos, inverse_class_name: 'EmbOne'
              end
              track_history
            end
          end

          after :each do
            Object.send(:remove_const, :MyModel)
          end

          it 'should not track embeds_many relation' do
            allow(MyModel).to receive(:dynamic_enabled?) { true }
            expect(MyModel.dynamic_field?(:emos)).to be false
          end
        end
      end
    end

    describe '#tracked_fields' do
      it 'should include fields and dynamic fields' do
        expect(MyTrackableModel.tracked_fields).to eq %w[foo my_dynamic_field]
      end
    end

    describe '#tracked_relation?' do
      it 'should return true if a relation is tracked' do
        expect(MyTrackableModel.tracked_relation?(:my_embed_one_model)).to be true
        expect(MyTrackableModel.tracked_relation?(:my_untracked_embed_one_model)).to be false
        expect(MyTrackableModel.tracked_relation?(:my_embed_many_models)).to be true
      end
    end

    describe '#tracked_embeds_one?' do
      it { expect(MyTrackableModel.tracked_embeds_one?(:my_embed_one_model)).to be true }
      it { expect(MyTrackableModel.tracked_embeds_one?(:my_untracked_embed_one_model)).to be false }
      it { expect(MyTrackableModel.tracked_embeds_one?(:my_embed_many_models)).to be false }
    end

    describe '#tracked_embeds_one' do
      it { expect(MyTrackableModel.tracked_embeds_one).to include 'my_embed_one_model' }
      it { expect(MyTrackableModel.tracked_embeds_one).to_not include 'my_untracked_embed_one_model' }
    end

    describe '#tracked_embeds_one_attributes' do
      before :each do
        class ModelOne
          include Mongoid::Document
          include Mongoid::History::Trackable

          if Mongoid::Compatibility::Version.mongoid7_or_newer?
            embeds_one :emb_one
            embeds_one :emb_two, store_as: :emt
            embeds_one :emb_three
          else
            embeds_one :emb_one, inverse_class_name: 'EmbOne'
            embeds_one :emb_two, store_as: :emt, inverse_class_name: 'EmbTwo'
            embeds_one :emb_three, inverse_class_name: 'EmbThree'
          end
        end

        class EmbOne
          include Mongoid::Document

          field :em_foo
          field :em_bar

          embedded_in :model_one
        end

        class EmbTwo
          include Mongoid::Document

          field :em_bar
          embedded_in :model_one
        end

        class EmbThree
          include Mongoid::Document

          field :em_baz
          embedded_in :model_one
        end
      end

      after :each do
        Object.send(:remove_const, :ModelOne)
        Object.send(:remove_const, :EmbOne)
        Object.send(:remove_const, :EmbTwo)
        Object.send(:remove_const, :EmbThree)
      end

      context 'when relation tracked' do
        before(:each) { ModelOne.track_history(on: :emb_one) }
        it { expect(ModelOne.tracked_embeds_one_attributes('emb_one')).to eq %w[_id em_foo em_bar] }
      end

      context 'when relation tracked with alias' do
        before(:each) { ModelOne.track_history(on: :emb_two) }
        it { expect(ModelOne.tracked_embeds_one_attributes('emb_two')).to eq %w[_id em_bar] }
      end

      context 'when relation tracked with attributes' do
        before(:each) { ModelOne.track_history(on: { emb_one: :em_foo }) }
        it { expect(ModelOne.tracked_embeds_one_attributes('emb_one')).to eq %w[_id em_foo] }
      end

      context 'when relation not tracked' do
        before(:each) { ModelOne.track_history(on: :fields) }
        it { expect(ModelOne.tracked_embeds_one_attributes('emb_one')).to be_nil }
      end
    end

    describe '#tracked_embeds_many?' do
      it { expect(MyTrackableModel.tracked_embeds_many?(:my_embed_one_model)).to be false }
      it { expect(MyTrackableModel.tracked_embeds_many?(:my_untracked_embed_one_model)).to be false }
      it { expect(MyTrackableModel.tracked_embeds_many?(:my_embed_many_models)).to be true }
    end

    describe '#tracked_embeds_many' do
      it { expect(MyTrackableModel.tracked_embeds_many).to eq ['my_embed_many_models'] }
    end

    describe '#tracked_embeds_many_attributes' do
      before :each do
        class ModelOne
          include Mongoid::Document
          include Mongoid::History::Trackable

          if Mongoid::Compatibility::Version.mongoid7_or_newer?
            embeds_many :emb_ones
            embeds_many :emb_twos, store_as: :emts
            embeds_many :emb_threes
          else
            embeds_many :emb_ones, inverse_class_name: 'EmbOne'
            embeds_many :emb_twos, store_as: :emts, inverse_class_name: 'EmbTwo'
            embeds_many :emb_threes, inverse_class_name: 'EmbThree'
          end
        end

        class EmbOne
          include Mongoid::Document

          field :em_foo
          field :em_bar

          embedded_in :model_one
        end

        class EmbTwo
          include Mongoid::Document

          field :em_bar
          embedded_in :model_one
        end

        class EmbThree
          include Mongoid::Document

          field :em_baz
          embedded_in :model_one
        end
      end

      after :each do
        Object.send(:remove_const, :ModelOne)
        Object.send(:remove_const, :EmbOne)
        Object.send(:remove_const, :EmbTwo)
        Object.send(:remove_const, :EmbThree)
      end

      context 'when relation tracked' do
        before(:each) { ModelOne.track_history(on: :emb_ones) }
        it { expect(ModelOne.tracked_embeds_many_attributes('emb_ones')).to eq %w[_id em_foo em_bar] }
      end

      context 'when relation tracked with alias' do
        before(:each) { ModelOne.track_history(on: :emb_twos) }
        it { expect(ModelOne.tracked_embeds_many_attributes('emb_twos')).to eq %w[_id em_bar] }
      end

      context 'when relation tracked with attributes' do
        before(:each) { ModelOne.track_history(on: { emb_ones: :em_foo }) }
        it { expect(ModelOne.tracked_embeds_many_attributes('emb_ones')).to eq %w[_id em_foo] }
      end

      context 'when relation not tracked' do
        before(:each) { ModelOne.track_history(on: :fields) }
        it { expect(ModelOne.tracked_embeds_many_attributes('emb_ones')).to be_nil }
      end
    end

    describe '#trackable_scope' do
      before :each do
        class ModelOne
          include Mongoid::Document
          include Mongoid::History::Trackable

          store_in collection: :model_ones

          track_history
        end
      end

      it { expect(ModelOne.trackable_scope).to eq(:model_one) }
    end

    describe '#clear_trackable_memoization' do
      before :each do
        MyTrackableModel.instance_variable_set(:@reserved_tracked_fields, %w[_id _type])
        MyTrackableModel.instance_variable_set(:@history_trackable_options, on: %w[fields])
        MyTrackableModel.instance_variable_set(:@trackable_settings, paranoia_field: 'deleted_at')
        MyTrackableModel.instance_variable_set(:@tracked_fields, %w[foo])
        MyTrackableModel.instance_variable_set(:@tracked_embeds_one, %w[my_embed_one_model])
        MyTrackableModel.instance_variable_set(:@tracked_embeds_many, %w[my_embed_many_models])
        MyTrackableModel.clear_trackable_memoization
      end

      it 'should clear all the trackable memoization' do
        expect(MyTrackableModel.instance_variable_get(:@reserved_tracked_fields)).to be_nil
        expect(MyTrackableModel.instance_variable_get(:@history_trackable_options)).to be_nil
        expect(MyTrackableModel.instance_variable_get(:@trackable_settings)).to be_nil
        expect(MyTrackableModel.instance_variable_get(:@tracked_fields)).to be_nil
        expect(MyTrackableModel.instance_variable_get(:@tracked_embeds_one)).to be_nil
        expect(MyTrackableModel.instance_variable_get(:@tracked_embeds_many)).to be_nil
      end
    end
  end
end
