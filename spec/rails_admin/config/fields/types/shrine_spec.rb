require 'spec_helper'

if defined?(Shrine)
  RSpec.describe RailsAdmin::Config::Fields::Types::Shrine do
    context 'when asset is an image with versions' do
      let(:record) { FactoryBot.create :field_test, shrine_versioning_asset: FakeIO.new('dummy', filename: 'test.jpg', content_type: 'image/jpeg') }
      let(:field) do
        RailsAdmin.config('FieldTest').fields.detect do |f|
          f.name == :shrine_versioning_asset
        end.with(object: record)
      end

      describe '#image?' do
        it 'returns true' do
          expect(field.image?).to be_truthy
        end
      end

      describe '#value' do
        context 'when attachment exists' do
          it 'returns attached object' do
            expect(field.value).to be_a(Hash)
          end
        end

        context 'when attachment does not exist' do
          let(:record) { FactoryBot.create :field_test }

          it 'returns nil' do
            expect(field.value).to be_nil
          end
        end
      end

      describe '#thumb_method' do
        it 'returns :thumb' do
          expect(field.thumb_method).to eq(:thumb)
        end
      end

      describe '#resource_url' do
        context 'when calling without thumb' do
          it 'returns original url' do
            expect(field.resource_url).to match(/original-/)
          end
        end

        context 'when calling with thumb' do
          it 'returns thumb url' do
            expect(field.resource_url(field.thumb_method)).to match(/thumb-/)
          end
        end
      end
    end

    context 'when asset without versions' do
      let(:record) { FactoryBot.create :field_test }
      let(:field) do
        RailsAdmin.config('FieldTest').fields.detect do |f|
          f.name == :shrine_asset
        end.with(object: record)
      end

      describe '#image?' do
        context 'when attachment is an image' do
          let(:record) { FactoryBot.create :field_test, shrine_asset: FakeIO.new('dummy', filename: 'test.jpg', content_type: 'image/jpeg') }

          it 'returns true' do
            expect(field.image?).to be_truthy
          end
        end

        context 'when attachment is not an image' do
          let(:record) { FactoryBot.create :field_test, shrine_asset: FakeIO.new('dummy', filename: 'test.txt', content_type: 'text/plain') }

          it 'returns false' do
            expect(field.image?).to be_falsy
          end
        end
      end

      describe '#value' do
        context 'when attachment exists' do
          let(:record) { FactoryBot.create :field_test, shrine_asset: FakeIO.new('dummy', filename: 'test.txt', content_type: 'text/plain') }

          it 'returns attached object' do
            expect(field.value).to be_a(ShrineUploader::UploadedFile)
          end
        end

        context 'when attachment does not exist' do
          it 'returns nil' do
            expect(field.value).to be_nil
          end
        end
      end

      describe '#thumb_method' do
        let(:record) { FactoryBot.create :field_test, shrine_asset: FakeIO.new('dummy', filename: 'test.jpg', content_type: 'image/jpeg') }

        it 'returns nil' do
          expect(field.thumb_method).to eq(nil)
        end
      end

      describe '#resource_url' do
        context 'when calling without thumb' do
          let(:record) { FactoryBot.create :field_test, shrine_asset: FakeIO.new('dummy', filename: 'test.txt', content_type: 'text/plain') }

          it 'returns url' do
            expect(field.resource_url).not_to be_nil
          end
        end

        context 'when calling with thumb' do
          let(:record) { FactoryBot.create :field_test, shrine_asset: FakeIO.new('dummy', filename: 'test.jpg', content_type: 'image/jpeg') }

          it 'returns url' do
            expect(field.resource_url(field.thumb_method)).not_to be_nil
          end
        end

        context 'when attachment does not exist' do
          it 'returns nil' do
            expect(field.resource_url).to be_nil
          end
        end
      end
    end
  end
end
