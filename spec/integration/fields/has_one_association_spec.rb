require 'spec_helper'

RSpec.describe 'HasOneAssociation field', type: :request do
  subject { page }

  describe 'with inverse_of option' do
    it 'adds a related id to the belongs_to create team link' do
      @player = FactoryBot.create :player
      visit edit_path(model_name: 'player', id: @player.id)
      is_expected.to have_selector("a[data-link='/admin/team/new?associations%5Bplayers%5D=#{@player.id}&modal=true']")
    end

    it 'adds a related id to the has_many create team link' do
      @team = FactoryBot.create :team
      visit edit_path(model_name: 'team', id: @team.id)
      is_expected.to have_selector("a[data-link='/admin/player/new?associations%5Bteam%5D=#{@team.id}&modal=true']")
    end
  end

  context 'on create' do
    before do
      @draft = FactoryBot.create :draft
    end

    it 'shows selects' do
      visit new_path(model_name: 'player')
      is_expected.to have_selector('select#player_draft_id')
    end

    it 'creates an object with correct associations' do
      post new_path(model_name: 'player', player: {name: 'Jackie Robinson', number: 42, position: 'Second baseman', draft_id: @draft.id})
      @player = RailsAdmin::AbstractModel.new('Player').all.to_a.detect { |player| player.name == 'Jackie Robinson' }
      @draft.reload
      expect(@player.draft).to eq(@draft)
    end
  end

  context 'on update' do
    before do
      @player = FactoryBot.create :player
      @draft = FactoryBot.create :draft
      @number = @draft.player.number + 1 # to avoid collision
      put edit_path(model_name: 'player', id: @player.id, player: {name: 'Jackie Robinson', draft_id: @draft.id, number: @number, position: 'Second baseman'})
      @player.reload
    end

    it 'updates an object with correct attributes' do
      expect(@player.name).to eq('Jackie Robinson')
      expect(@player.number).to eq(@number)
      expect(@player.position).to eq('Second baseman')
    end

    it 'updates an object with correct associations' do
      @draft.reload
      expect(@player.draft).to eq(@draft)
    end
  end

  describe 'on show' do
    before do
      @player = FactoryBot.create :player
      @draft  = FactoryBot.create :draft, player: @player
      visit show_path(model_name: 'player', id: @player.id)
    end

    it 'shows associated objects' do
      is_expected.to have_css("a[href='/admin/draft/#{@draft.id}']")
    end
  end

  describe 'nested form' do
    it 'works', js: true do
      @record = FactoryBot.create :field_test
      visit edit_path(model_name: 'field_test', id: @record.id)

      find('#field_test_comment_attributes_field .add_nested_fields').click
      fill_in 'field_test_comment_attributes_content', with: 'nested comment content'

      # trigger click via JS, workaround for instability in CI
      execute_script %($('button[name="_save"]').trigger('click');)
      is_expected.to have_content('Field test successfully updated')

      @record.reload
      expect(@record.comment.content.strip).to eq('nested comment content')
    end

    it 'is optional' do
      @record = FactoryBot.create :field_test
      visit edit_path(model_name: 'field_test', id: @record.id)
      click_button 'Save'
      @record.reload
      expect(@record.comment).to be_nil
    end

    context 'when XSS attack is attempted', js: true do
      it 'does not break on adding a new item' do
        allow(I18n).to receive(:t).and_call_original
        expect(I18n).to receive(:t).with('admin.form.new_model', name: 'Comment').and_return('<script>throw "XSS";</script>')
        @record = FactoryBot.create :field_test
        visit edit_path(model_name: 'field_test', id: @record.id)
        find('#field_test_comment_attributes_field .add_nested_fields').click
      end

      it 'does not break on adding an existing item' do
        RailsAdmin.config Comment do
          object_label_method :content
        end
        @record = FactoryBot.create :field_test
        FactoryBot.create :comment, content: '<script>throw "XSS";</script>', commentable: @record
        visit edit_path(model_name: 'field_test', id: @record.id)
      end
    end
  end

  context 'with custom primary_key option' do
    let(:user) { FactoryBot.create :managing_user }
    let!(:team) { FactoryBot.create(:managed_team) }
    before do
      RailsAdmin.config.included_models = [ManagingUser, ManagedTeam]
      RailsAdmin.config ManagingUser do
        field :team
      end
    end

    it 'allows update' do
      visit edit_path(model_name: 'managing_user', id: user.id)
      select(team.name, from: 'Team')
      click_button 'Save'
      expect(ManagingUser.first.team).to eq team
    end

    context 'when fetching associated objects via xhr' do
      before do
        RailsAdmin.config ManagingUser do
          field(:team) { associated_collection_cache_all false }
        end
      end

      it 'allows update', js: true do
        visit edit_path(model_name: 'managing_user', id: user.id)
        find('input.ra-filtering-select-input').set('T')
        page.execute_script("$('input.ra-filtering-select-input').trigger('focus')")
        page.execute_script("$('input.ra-filtering-select-input').trigger('keydown')")
        expect(page).to have_selector('ul.ui-autocomplete li.ui-menu-item a')
        page.execute_script %{$('ul.ui-autocomplete li.ui-menu-item a:contains("#{team.name}")').trigger('mouseenter').click()}
        click_button 'Save'
        expect(ManagingUser.first.team).to eq team
      end
    end
  end
end
