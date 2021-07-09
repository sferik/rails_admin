require 'spec_helper'

RSpec.describe 'ActiveRecordEnum field', type: :request, active_record: true do
  subject { page }

  describe 'for string-keyed enum' do
    before do
      RailsAdmin.config FieldTest do
        edit do
          field :string_enum_field do
            default_value 'MEDIUM'
          end
        end
      end
    end

    it 'auto-detects enumeration' do
      visit new_path(model_name: 'field_test')
      is_expected.to have_selector('.enum_type select')
      is_expected.not_to have_selector('.enum_type select[multiple]')
      expect(all('.enum_type option').map(&:text).select(&:present?)).to eq %w(SMALL MEDIUM LARGE)
    end

    it 'shows current value as selected' do
      field_test = FieldTest.create(string_enum_field: 'LARGE')
      puts field_test.string_enum_field
      puts field_test.attributes
      visit edit_path(model_name: 'field_test', id: field_test)
      expect(find('.enum_type select').value).to eq 'l'
    end

    it 'can be updated' do
      visit edit_path(model_name: 'field_test', id: FieldTest.create(string_enum_field: 'SMALL'))
      select 'LARGE'
      click_button 'Save'
      expect(FieldTest.first.string_enum_field).to eq 'LARGE'
    end

    it 'pre-populates default value' do
      visit new_path(model_name: 'field_test')
      expect(find('.enum_type select').value).to eq 'm'
    end
  end

  describe 'for integer-keyed enum' do
    before do
      RailsAdmin.config FieldTest do
        edit do
          field :integer_enum_field do
            default_value :medium
          end
        end
      end
    end

    it 'auto-detects enumeration' do
      visit new_path(model_name: 'field_test')
      is_expected.to have_selector('.enum_type select')
      is_expected.not_to have_selector('.enum_type select[multiple]')
      expect(all('.enum_type option').map(&:text).select(&:present?)).to eq %w(small medium large)
    end

    it 'shows current value as selected' do
      visit edit_path(model_name: 'field_test', id: FieldTest.create(integer_enum_field: :large))
      expect(find('.enum_type select').value).to eq "2"
    end

    it 'can be updated' do
      visit edit_path(model_name: 'field_test', id: FieldTest.create(integer_enum_field: :small))
      select 'large'
      click_button 'Save'
      expect(FieldTest.first.integer_enum_field).to eq "large"
    end

    it 'pre-populates default value' do
      visit new_path(model_name: 'field_test')
      expect(find('.enum_type select').value).to eq "1"
    end
  end
end
