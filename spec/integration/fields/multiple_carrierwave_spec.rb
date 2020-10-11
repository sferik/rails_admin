require 'spec_helper'

RSpec.describe 'MultipleCarrierwave field', type: :request, active_record: true do
  subject { page }
  before do
    RailsAdmin.config FieldTest do
      edit do
        field :carrierwave_assets
      end
    end
  end

  it 'supports uploading multiple files' do
    visit new_path(model_name: 'field_test')
    attach_file 'Carrierwave assets', [file_path('test.jpg'), file_path('test.png')]
    click_button 'Save'
    expect(FieldTest.first.carrierwave_assets.map { |image| File.basename(image.url) }).to match_array ['test.jpg', 'test.png']
  end

  context 'when working with existing files' do
    let(:field_test) { FactoryBot.create(:field_test, carrierwave_assets: ['test.jpg', 'test.png'].map { |img| File.open(file_path(img)) }) }

    it 'supports appending a file', js: true do
      visit edit_path(model_name: 'field_test', id: field_test.id)
      attach_file 'Carrierwave assets', [file_path('test.gif')]
      click_button 'Save'
      field_test.reload
      expect(field_test.carrierwave_assets.map { |image| File.basename(image.url) }).to eq ['test.jpg', 'test.png', 'test.gif']
    end

    it 'supports deleting a file', js: true do
      visit edit_path(model_name: 'field_test', id: field_test.id)
      click_link 'Delete carrierwave assets #1'
      click_button 'Save'
      field_test.reload
      expect(field_test.carrierwave_assets.map { |image| File.basename(image.url) }).to eq ['test.png']
    end

    it 'supports reordering files', js: true do
      visit edit_path(model_name: 'field_test', id: field_test.id)
      page.execute_script File.read(File.expand_path('../../support/jquery.simulate.drag-sortable.js', __dir__))
      page.execute_script %{$(".ui-sortable-handle:first-child").simulateDragSortable({ move: 1});}
      click_button 'Save'
      field_test.reload
      expect(field_test.carrierwave_assets.map { |image| File.basename(image.url) }).to eq ['test.png', 'test.jpg']
    end
  end
end
