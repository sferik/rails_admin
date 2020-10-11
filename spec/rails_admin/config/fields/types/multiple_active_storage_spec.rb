require 'spec_helper'

if defined?(ActiveStorage)
  RSpec.describe RailsAdmin::Config::Fields::Types::MultipleActiveStorage do
    it_behaves_like 'a generic field type', :string_field, :multiple_active_storage

    let(:record) { FactoryBot.create :field_test }
    let(:field) do
      RailsAdmin.config('FieldTest').fields.detect do |f|
        f.name == :active_storage_assets
      end.with(object: record)
    end

    describe RailsAdmin::Config::Fields::Types::MultipleActiveStorage::ActiveStorageAttachment do
      describe '#image?' do
        context 'when attachment is an image' do
          let(:record) { FactoryBot.create :field_test, active_storage_assets: [{io: StringIO.new('dummy'), filename: 'test.jpg', content_type: 'image/jpeg'}] }

          it 'returns true' do
            expect(field.attachments[0].image?).to be_truthy
          end
        end

        context 'when attachment is not an image' do
          let(:record) { FactoryBot.create :field_test, active_storage_assets: [{io: StringIO.new('dummy'), filename: 'test.txt', content_type: 'text/plain'}] }

          it 'returns false' do
            expect(field.attachments[0].image?).to be_falsy
          end
        end
      end

      describe '#resource_url' do
        context 'when calling with thumb = false' do
          let(:record) { FactoryBot.create :field_test, active_storage_assets: [{io: StringIO.new('dummy'), filename: 'test.jpg', content_type: 'image/jpeg'}] }

          it 'returns original url' do
            expect(field.attachments[0].resource_url).not_to match(/representations/)
          end
        end

        context 'when attachment is an image' do
          let(:record) { FactoryBot.create :field_test, active_storage_assets: [{io: StringIO.new('dummy'), filename: 'test.jpg', content_type: 'image/jpeg'}] }

          it 'returns variant\'s url' do
            expect(field.attachments[0].resource_url(true)).to match(/representations/)
          end
        end

        context 'when attachment is not an image' do
          let(:record) { FactoryBot.create :field_test, active_storage_assets: [{io: StringIO.new('dummy'), filename: 'test.txt', content_type: 'text/plain'}] }

          it 'returns original url' do
            expect(field.attachments[0].resource_url(true)).not_to match(/representations/)
          end
        end
      end
    end
  end
end
