require 'spec_helper'

RSpec.describe 'Shrine field', type: :request, active_record: true do
  subject { page }
  before do
    RailsAdmin.config FieldTest do
      edit do
        field :string_field
        field :shrine_asset
      end
    end
  end

  it 'supports caching an uploaded file', js: true do
    visit new_path(model_name: 'field_test')
    attach_file 'Shrine asset', file_path('test.jpg')
    fill_in 'field_test[string_field]', with: 'Invalid'
    click_button 'Save'
    expect(page).to have_content 'Field test failed to be created'
    fill_in 'field_test[string_field]', with: ''
    click_button 'Save'
    expect(FieldTest.first.shrine_asset).to exist
  end
end
