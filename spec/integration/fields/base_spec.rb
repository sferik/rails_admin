require 'spec_helper'

RSpec.describe 'Base field', type: :request do
  subject { page }

  describe '#default_value' do
    it 'is set for all types of input fields' do
      RailsAdmin.config do |config|
        config.excluded_models = []
        config.model(FieldTest) do
          field :string_field do
            default_value 'string_field default_value'
          end
          field :text_field do
            default_value 'string_field text_field'
          end
          field :boolean_field do
            default_value true
          end
          field :date_field do
            default_value Date.today
          end
        end
      end

      visit new_path(model_name: 'field_test')
      # In Rails 3.2.3 behavior of textarea has changed to insert newline after the opening tag,
      # but Capybara's RackTest driver is not up to this behavior change.
      # (https://github.com/jnicklas/capybara/issues/677)
      # So we manually cut off first newline character as a workaround here.
      expect(find_field('field_test[string_field]').value.gsub(/^\n/, '')).to eq('string_field default_value')
      expect(find_field('field_test[text_field]').value.gsub(/^\n/, '')).to eq('string_field text_field')
      expect(find_field('field_test[date_field]').value).to eq(Date.today.to_s)
      expect(has_checked_field?('field_test[boolean_field]')).to be_truthy
    end

    it 'sets default value for selects' do
      RailsAdmin.config(Team) do
        field :color, :enum do
          default_value 'black'
          enum do
            %w[black white]
          end
        end
      end
      visit new_path(model_name: 'team')
      expect(find_field('team[color]').value).to eq('black')
    end

    it 'renders custom value next time if error happend' do
      RailsAdmin.config(Team) do
        field :name do
          render do
            bindings[:object].persisted? ? 'Custom Name' : raise(ZeroDivisionError)
          end
        end
      end
      expect { visit new_path(model_name: 'team') }.to raise_error(/ZeroDivisionError/)
      record = FactoryBot.create(:team)
      visit edit_path(model_name: 'team', id: record.id)
      expect(page).to have_content('Custom Name')
    end
  end

  describe '#bindings' do
    it 'is available' do
      RailsAdmin.config do |config|
        config.excluded_models = []
      end
      RailsAdmin.config Category do
        field :parent_category do
          visible do
            !bindings[:object].new_record?
          end
        end
      end

      visit new_path(model_name: 'category')
      is_expected.to have_no_css('#category_parent_category_id')
      click_button 'Save' # first(:button, "Save").click
      visit edit_path(model_name: 'category', id: Category.first)
      is_expected.to have_css('#category_parent_category_id')
      click_button 'Save' # first(:button, "Save").click
      is_expected.to have_content('Category successfully updated')
    end
  end
end
