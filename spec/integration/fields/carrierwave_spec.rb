require 'spec_helper'

RSpec.describe 'Carrierwave field', type: :request, active_record: true do
  subject { page }
  before do
    RailsAdmin.config FieldTest do
      edit do
        field :string_field
        field :carrierwave_asset
      end
    end
  end

  it 'supports caching an uploaded file' do
    visit new_path(model_name: 'field_test')
    attach_file 'Carrierwave asset', file_path('test.jpg')
    fill_in 'field_test[string_field]', with: 'Invalid'
    click_button 'Save'
    expect(page).to have_content 'Field test failed to be created'
    fill_in 'field_test[string_field]', with: ''
    click_button 'Save'
    expect(FieldTest.first.carrierwave_asset.file).to exist
  end
end
