require 'spec_helper'

RSpec.describe 'FilteringMultiSelect widget', type: :request, js: true do
  subject { page }

  describe 'Choose all button' do
    let(:team) { FactoryBot.create :team }
    let!(:players) { FactoryBot.create_list :player, 2 }
    before do
      RailsAdmin.config Team do
        field :players
      end
    end

    it 'picks all available items' do
      visit edit_path(model_name: 'team', id: team.id)
      click_link 'Choose all'
      expect(all(:css, '#team_player_ids option', visible: false).map(&:value)).to match_array players.map(&:id).map(&:to_s)
    end

    context 'when associated_collection_cache_all is false' do
      before do
        RailsAdmin.config Team do
          field(:players) { associated_collection_cache_all false }
        end
      end

      it 'does not pick the placeholder for selection' do
        visit edit_path(model_name: 'team', id: team.id)
        click_link 'Choose all'
        expect(page).not_to have_css('#team_player_ids option', visible: false)
        expect(page).not_to have_css('.ra-multiselect-selection option')
      end

      it 'picks all available items' do
        visit edit_path(model_name: 'team', id: team.id)
        find('input.ra-multiselect-search').set('P')
        page.execute_script("$('input.ra-multiselect-search').trigger('focus')")
        page.execute_script("$('input.ra-multiselect-search').trigger('keydown')")
        expect(page).to have_css('.ra-multiselect-collection option', text: /Player/)
        click_link 'Choose all'
        expect(all(:css, '#team_player_ids option', visible: false).map(&:value)).to match_array players.map(&:id).map(&:to_s)
      end
    end
  end
end
