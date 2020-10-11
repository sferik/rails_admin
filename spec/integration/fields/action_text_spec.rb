require 'spec_helper'

if defined?(ActionText)
  RSpec.describe 'ActionText field', type: :request do
    subject { page }

    it 'works without error', js: true do
      RailsAdmin.config FieldTest do
        edit do
          field :action_text_field
        end
      end
      expect { visit new_path(model_name: 'field_test') }.not_to raise_error
      is_expected.to have_selector('trix-toolbar')
    end
  end
end
