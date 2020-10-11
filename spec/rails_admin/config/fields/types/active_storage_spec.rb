require 'spec_helper'

if defined?(ActiveStorage)
  RSpec.describe RailsAdmin::Config::Fields::Types::ActiveStorage do
    it_behaves_like 'a generic field type', :string_field, :active_storage

    let(:record) { FactoryBot.create :field_test }
    let(:field) do
      RailsAdmin.config('FieldTest').fields.detect do |f|
        f.name == :active_storage_asset
      end.with(object: record)
    end

    describe '#image?' do
      context 'when attachment is an image' do
        let(:record) { FactoryBot.create :field_test, active_storage_asset: {io: StringIO.new('dummy'), filename: 'test.jpg', content_type: 'image/jpeg'} }

        it 'returns true' do
          expect(field.image?).to be_truthy
        end
      end

      context 'when attachment is not an image' do
        let(:record) { FactoryBot.create :field_test, active_storage_asset: {io: StringIO.new('dummy'), filename: 'test.txt', content_type: 'text/plain'} }

        it 'returns false' do
          expect(field.image?).to be_falsy
        end
      end
    end

    describe '#resource_url' do
      context 'when calling with thumb = false' do
        let(:record) { FactoryBot.create :field_test, active_storage_asset: {io: StringIO.new('dummy'), filename: 'test.jpg', content_type: 'image/jpeg'} }

        it 'returns original url' do
          expect(field.resource_url).not_to match(/representations/)
        end
      end

      context 'when attachment is an image' do
        let(:record) { FactoryBot.create :field_test, active_storage_asset: {io: StringIO.new('dummy'), filename: 'test.jpg', content_type: 'image/jpeg'} }

        it 'returns variant\'s url' do
          expect(field.resource_url(true)).to match(/representations/)
        end
      end

      context 'when attachment is not an image' do
        let(:record) { FactoryBot.create :field_test, active_storage_asset: {io: StringIO.new('dummy'), filename: 'test.txt', content_type: 'text/plain'} }

        it 'returns original url' do
          expect(field.resource_url(true)).not_to match(/representations/)
        end
      end
    end

    describe '#value' do
      context 'when attachment exists' do
        let(:record) { FactoryBot.create :field_test, active_storage_asset: {io: StringIO.new('dummy'), filename: 'test.jpg', content_type: 'image/jpeg'} }

        it 'returns attached object' do
          expect(field.value).to be_a(ActiveStorage::Attached::One)
        end
      end

      context 'when attachment does not exist' do
        let(:record) { FactoryBot.create :field_test }

        it 'returns nil' do
          expect(field.value).to be_nil
        end
      end
    end
  end
end
