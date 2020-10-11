require 'spec_helper'

RSpec.describe RailsAdmin::Config::Fields::Types::MultipleFileUpload do
  it_behaves_like 'a generic field type', :string_field, :multiple_file_upload

  describe '#allowed_methods' do
    it 'includes delete_method and cache_method' do
      RailsAdmin.config do |config|
        config.model FieldTest do
          field :carrierwave_assets, :multiple_carrierwave
          if defined?(ActiveStorage)
            field :active_storage_assets, :multiple_active_storage do
              delete_method :remove_active_storage_assets
            end
          end
        end
      end
      expect(RailsAdmin.config(FieldTest).field(:carrierwave_assets).with(object: FieldTest.new).allowed_methods.collect(&:to_s)).to eq %w[carrierwave_assets]
      expect(RailsAdmin.config(FieldTest).field(:active_storage_assets).with(object: FieldTest.new).allowed_methods.collect(&:to_s)).to eq %w[active_storage_assets remove_active_storage_assets] if defined?(ActiveStorage)
    end
  end

  describe '#html_attributes' do
    context 'when the field is required and value is already set' do
      before do
        RailsAdmin.config FieldTest do
          field :string_field, :multiple_file_upload do
            required true
          end
        end
      end

      let :rails_admin_field do
        RailsAdmin.config('FieldTest').fields.detect do |f|
          f.name == :string_field
        end.with(object: FieldTest.new(string_field: 'dummy.jpg'))
      end

      it 'does not have a required attribute' do
        expect(rails_admin_field.html_attributes[:required]).to be_falsy
      end
    end
  end

  describe '#pretty_value' do
    before do
      RailsAdmin.config FieldTest do
        field :string_field, :multiple_file_upload do
          attachment do
            thumb_method 'thumb'

            def resource_url(thumb = false)
              if thumb
                "http://example.com/#{thumb}/#{value}"
              else
                "http://example.com/#{value}"
              end
            end
          end
        end
      end
    end

    let(:filename) { '' }

    let :rails_admin_field do
      RailsAdmin.config('FieldTest').fields.detect do |f|
        f.name == :string_field
      end.with(
        object: FieldTest.new(string_field: filename),
        view: ApplicationController.new.view_context,
      )
    end

    context 'when the field is not an image' do
      let(:filename) { 'dummy.txt' }

      it 'uses filename as link text' do
        expect(Nokogiri::HTML(rails_admin_field.pretty_value).text).to eq 'dummy.txt'
      end
    end

    context 'when the field is an image' do
      let(:filename) { 'dummy.jpg' }

      subject { Nokogiri::HTML(rails_admin_field.pretty_value) }

      it 'shows thumbnail image with a link' do
        expect(subject.css('img').attribute('src').value).to eq 'http://example.com/thumb/dummy.jpg'
        expect(subject.css('a').attribute('href').value).to eq 'http://example.com/dummy.jpg'
      end
    end
  end

  describe '#attachment' do
    before do
      RailsAdmin.config FieldTest do
        field :string_field, :multiple_file_upload do
          attachment do
            delete_value 'something'

            def resource_url(_thumb = false)
              "http://example.com/#{value}"
            end
          end

          def value
            ['foo.jpg']
          end
        end
      end
    end

    let :rails_admin_field do
      RailsAdmin.config('FieldTest').fields.detect do |f|
        f.name == :string_field
      end.with(
        view: ApplicationController.new.view_context,
      )
    end

    it 'enables configuration' do
      expect(rails_admin_field.attachments.map(&:delete_value)).to eq ['something']
      expect(rails_admin_field.attachments.map(&:resource_url)).to eq ['http://example.com/foo.jpg']
      expect(rails_admin_field.pretty_value).to match(%r{src="http://example.com/foo.jpg"})
    end
  end

  describe '#attachments' do
    before do
      RailsAdmin.config FieldTest do
        field :string_field, :multiple_file_upload
      end
    end

    let :rails_admin_field do
      RailsAdmin.config('FieldTest').fields.detect do |f|
        f.name == :string_field
      end
    end

    it 'wraps value with Array()' do
      expect(rails_admin_field.with(object: FieldTest.new(string_field: nil)).attachments).to eq []
      expect(rails_admin_field.with(object: FieldTest.new(string_field: 'dummy.txt')).attachments.map(&:value)).to eq ['dummy.txt']
    end
  end
end
