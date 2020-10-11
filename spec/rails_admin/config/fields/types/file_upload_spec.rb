require 'spec_helper'

RSpec.describe RailsAdmin::Config::Fields::Types::FileUpload do
  it_behaves_like 'a generic field type', :string_field, :file_upload

  describe '#allowed_methods' do
    it 'includes delete_method and cache_method' do
      RailsAdmin.config do |config|
        config.model FieldTest do
          field :carrierwave_asset
          field :dragonfly_asset
          field :paperclip_asset do
            delete_method :delete_paperclip_asset
          end
          if defined?(ActiveStorage)
            field :active_storage_asset do
              delete_method :remove_active_storage_asset
            end
          end
          if defined?(Shrine)
            field :shrine_asset do
              delete_method :remove_shrine_asset
              cache_method :cached_shrine_asset_data
            end
          end
        end
      end
      expect(RailsAdmin.config(FieldTest).field(:carrierwave_asset).allowed_methods.collect(&:to_s)).to eq %w[carrierwave_asset remove_carrierwave_asset carrierwave_asset_cache]
      expect(RailsAdmin.config(FieldTest).field(:dragonfly_asset).allowed_methods.collect(&:to_s)).to eq %w[dragonfly_asset remove_dragonfly_asset retained_dragonfly_asset]
      expect(RailsAdmin.config(FieldTest).field(:paperclip_asset).allowed_methods.collect(&:to_s)).to eq %w[paperclip_asset delete_paperclip_asset]
      expect(RailsAdmin.config(FieldTest).field(:active_storage_asset).allowed_methods.collect(&:to_s)).to eq %w[active_storage_asset remove_active_storage_asset] if defined?(ActiveStorage)
      expect(RailsAdmin.config(FieldTest).field(:shrine_asset).allowed_methods.collect(&:to_s)).to eq %w[shrine_asset remove_shrine_asset cached_shrine_asset_data] if defined?(Shrine)
    end
  end

  describe '#html_attributes' do
    context 'when the field is required and value is already set' do
      before do
        RailsAdmin.config FieldTest do
          field :string_field, :file_upload do
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
    context 'when the field is not image' do
      before do
        RailsAdmin.config FieldTest do
          field :string_field, :file_upload do
            def resource_url
              'http://example.com/dummy.txt'
            end
          end
        end
      end

      let :rails_admin_field do
        RailsAdmin.config('FieldTest').fields.detect do |f|
          f.name == :string_field
        end.with(
          object: FieldTest.new(string_field: 'dummy.txt'),
          view: ApplicationController.new.view_context,
        )
      end

      it 'uses filename as link text' do
        expect(Nokogiri::HTML(rails_admin_field.pretty_value).text).to eq 'dummy.txt'
      end
    end
  end
end
