require 'spec_helper'

RSpec.describe RailsAdmin::Config::Fields::Types::Datetime do
  it_behaves_like 'a generic field type', :datetime_field, :datetime

  describe '#formatted_value' do
    it 'gets object value' do
      field = RailsAdmin.config(FieldTest).fields.detect do |f|
        f.name == :datetime_field
      end.with(object: FieldTest.new(datetime_field: DateTime.parse('02/01/2012')))

      expect(field.formatted_value).to eq 'January 02, 2012 00:00'
    end

    it 'gets default value for new objects if value is nil' do
      RailsAdmin.config(FieldTest) do |_config|
        field :datetime_field do
          default_value DateTime.parse('01/01/2012')
        end
      end

      field = RailsAdmin.config(FieldTest).fields.detect do |f|
        f.name == :datetime_field
      end.with(object: FieldTest.new)

      expect(field.formatted_value).to eq 'January 01, 2012 00:00'
    end
  end

  describe '#parse_input' do
    let(:field) { RailsAdmin.config(FieldTest).fields.detect { |f| f.name == :datetime_field } }

    before :each do
      @object = FactoryBot.create(:field_test)
      @time = ::Time.now.getutc
    end

    after :each do
      Time.zone = 'UTC'
    end

    it 'is able to read %B %-d, %Y %H:%M' do
      @object = FactoryBot.create(:field_test)
      @object.datetime_field = field.parse_input(datetime_field: @time.strftime('%B %-d, %Y %H:%M'))
      expect(@object.datetime_field.strftime('%Y-%m-%d %H:%M')).to eq(@time.strftime('%Y-%m-%d %H:%M'))
    end

    it 'is able to read %a, %d %b %Y %H:%M:%S %z' do
      RailsAdmin.config FieldTest do
        field :datetime_field do
          date_format do
            :default
          end
        end
      end

      @object = FactoryBot.create(:field_test)
      @object.datetime_field = field.parse_input(datetime_field: @time.strftime('%a, %d %b %Y %H:%M:%S %z'))
      expect(@object.datetime_field.to_s(:rfc822)).to eq(@time.to_s(:rfc822))
    end

    it 'has a customization option' do
      RailsAdmin.config FieldTest do
        field :datetime_field do
          strftime_format do
            '%Y-%m-%d %H:%M:%S'
          end
        end
      end

      @object = FactoryBot.create(:field_test)
      @object.datetime_field = field.parse_input(datetime_field: @time.strftime('%Y-%m-%d %H:%M:%S'))
      expect(@object.datetime_field.to_s(:rfc822)).to eq(@time.to_s(:rfc822))
    end

    it 'does round-trip saving properly with non-UTC timezones' do
      RailsAdmin.config FieldTest do
        field :datetime_field do
          date_format do
            :default
          end
        end
      end

      Time.zone = 'Vienna'
      @object = FactoryBot.create(:field_test)
      @object.datetime_field = field.parse_input(datetime_field: 'Sat, 01 Sep 2012 12:00:00 +0200')
      expect(@object.datetime_field).to eq(Time.zone.parse('2012-09-01 12:00:00 +02:00'))
    end

    it 'changes formats when the locale changes' do
      french_format = '%A %d %B %Y %H:%M'
      allow(I18n).to receive(:t).with(:long, scope: %i[time formats], raise: true).and_return(french_format)
      @object = FactoryBot.create(:field_test)
      @object.datetime_field = field.parse_input(datetime_field: @time.strftime(french_format))
      expect(@object.datetime_field.strftime(french_format)).to eq(@time.strftime(french_format))

      american_format = '%B %d, %Y %H:%M'
      allow(I18n).to receive(:t).with(:long, scope: %i[time formats], raise: true).and_return(american_format)
      @object = FactoryBot.create(:field_test)
      @object.datetime_field = field.parse_input(datetime_field: @time.strftime(american_format))
      expect(@object.datetime_field.strftime(american_format)).to eq(@time.strftime(american_format))
    end
  end
end
