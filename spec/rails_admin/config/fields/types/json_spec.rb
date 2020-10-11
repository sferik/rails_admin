require 'spec_helper'

RSpec.describe RailsAdmin::Config::Fields::Types::Json do
  let(:field) { RailsAdmin.config(FieldTest).fields.detect { |f| f.name == :json_field } }
  let(:object) { FieldTest.new }
  let(:bindings) do
    {
      object: object,
      view: ApplicationController.new.view_context,
    }
  end

  describe '#formatted_value' do
    before do
      RailsAdmin.config do |config|
        config.model FieldTest do
          field :json_field, :json
        end
      end
    end

    it 'returns correct value for empty json' do
      allow(object).to receive(:json_field) { {} }
      actual = field.with(bindings).formatted_value
      expect(actual).to match(/{\n+}/)
    end

    it 'retuns correct value' do
      allow(object).to receive(:json_field) { {sample_key: 'sample_value'} }
      actual = field.with(bindings).formatted_value
      expected = [
        '{',
        '  "sample_key": "sample_value"',
        '}',
      ].join("\n")
      expect(actual).to eq(expected)
    end
  end

  describe '#pretty_value' do
    before do
      RailsAdmin.config do |config|
        config.model FieldTest do
          field :json_field, :json
        end
      end
    end

    it 'retuns correct value' do
      allow(object).to receive(:json_field) { {sample_key: 'sample_value'} }
      actual = field.with(bindings).pretty_value
      expected = [
        '<pre>{',
        '  &quot;sample_key&quot;: &quot;sample_value&quot;',
        '}</pre>',
      ].join("\n")
      expect(actual).to eq(expected)
    end
  end

  describe '#export_value' do
    before do
      RailsAdmin.config do |config|
        config.model FieldTest do
          field :json_field, :json
        end
      end
    end

    it 'returns correct value for empty json' do
      allow(object).to receive(:json_field) { {} }
      actual = field.with(bindings).export_value
      expect(actual).to match(/{\n+}/)
    end

    it 'returns correct value' do
      allow(object).to receive(:json_field) { {sample_key: 'sample_value'} }
      actual = field.with(bindings).export_value
      expected = [
        '{',
        '  "sample_key": "sample_value"',
        '}',
      ].join("\n")
      expect(actual).to eq(expected)
    end
  end

  describe '#parse_input' do
    before :each do
      RailsAdmin.config do |config|
        config.model FieldTest do
          field :json_field, :json
        end
      end
    end

    it 'parse valid json string' do
      data = {string: 'string', integer: 1, array: [1, 2, 3], object: {bla: 'foo'}}.as_json
      expect(field.parse_input(json_field: data.to_json)).to eq data
    end

    it 'raise JSON::ParserError with invalid json string' do
      expect { field.parse_input(json_field: '{{') }.to raise_error(JSON::ParserError)
    end
  end

  describe 'aliasing' do
    before :each do
      RailsAdmin.config do |config|
        config.model FieldTest do
          field :json_field, :jsonb
        end
      end
    end

    it 'allows use of :jsonb fieldtype' do
      expect(field.class).to eq RailsAdmin::Config::Fields::Types::Json
    end
  end

  it_behaves_like 'a generic field type', :text, :json
end
