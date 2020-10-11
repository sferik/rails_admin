require 'spec_helper'

RSpec.describe 'Base action', type: :request do
  subject { page }

  describe '#enabled?' do
    it 'prevents the access to unauthorized actions' do
      RailsAdmin.config do |config|
        config.actions do
          index do
            except %w[FieldTest]
          end
        end
      end
      expect { visit index_path(model_name: 'field_test') }.to raise_error 'RailsAdmin::ActionNotAllowed'
    end

    describe 'in form action' do
      before do
        RailsAdmin.config do |config|
          config.actions do
            index
            new
            edit do
              except %w[Player Team]
            end
          end
        end
      end

      describe 'for filterling-select widget' do
        it 'hides modal links to disabled actions' do
          visit new_path(model_name: 'player')
          expect(page).to have_link 'Add a new Team'
          expect(page).not_to have_link 'Edit this Team'
        end
      end

      describe 'for filterling-multiselect widget' do
        it 'hides edit link to another model' do
          visit new_path(model_name: 'team')
          expect(page).to have_link 'Add a new Player'
          expect(page).not_to have_link 'Edit this Player'
        end
      end
    end
  end
end
