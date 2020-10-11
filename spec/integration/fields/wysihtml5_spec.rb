require 'spec_helper'

RSpec.describe 'Wysihtml5 field', type: :request do
  subject { page }

  it 'works without error', js: true do
    RailsAdmin.config Draft do
      edit do
        field :notes, :wysihtml5
      end
    end
    expect { visit new_path(model_name: 'draft') }.not_to raise_error
    is_expected.to have_selector('.wysihtml5-toolbar')
  end

  it 'should include custom wysihtml5 configuration' do
    RailsAdmin.config Draft do
      edit do
        field :notes, :wysihtml5 do
          config_options image: false
          css_location 'stub_css.css'
          js_location 'stub_js.js'
        end
      end
    end

    visit new_path(model_name: 'draft')
    is_expected.to have_selector('textarea#draft_notes[data-richtext="bootstrap-wysihtml5"][data-options]')
  end
end
