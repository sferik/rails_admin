require 'spec_helper'

RSpec.describe 'RailsAdmin Pundit Authorization', type: :request do
  subject { page }

  before do
    RailsAdmin.config do |c|
      c.authorize_with(:pundit)
      c.authenticate_with { warden.authenticate! scope: :user }
      c.current_user_method(&:current_user)
    end
    @player_model = RailsAdmin::AbstractModel.new(Player)
    @user = FactoryBot.create :user, roles: []
    login_as @user
  end

  describe 'with no roles' do
    it 'GET /admin should raise Pundit::NotAuthorizedError' do
      expect { visit dashboard_path }.to raise_error(Pundit::NotAuthorizedError)
    end

    it 'GET /admin/player should raise Pundit::NotAuthorizedError' do
      expect { visit index_path(model_name: 'player') }.to raise_error(Pundit::NotAuthorizedError)
    end
  end

  describe 'with read player role' do
    before do
      @user.update(roles: %i[admin read_player])
    end

    it 'GET /admin should show Player but not League' do
      visit dashboard_path
      is_expected.to have_content('Player')
      is_expected.not_to have_content('League')
      is_expected.not_to have_content('Add new')
    end

    it 'GET /admin/team should raise Pundit::NotAuthorizedError' do
      expect { visit index_path(model_name: 'team') }.to raise_error(Pundit::NotAuthorizedError)
    end

    it 'GET /admin/player/1/edit should raise access denied' do
      @player = FactoryBot.create :player
      expect { visit edit_path(model_name: 'player', id: @player.id) }.to raise_error(Pundit::NotAuthorizedError)
    end
  end

  describe 'with admin role' do
    before do
      @user.update(roles: %i[admin manage_player])
    end

    it 'GET /admin should show Player but not League' do
      visit dashboard_path
      is_expected.to have_content('Player')
    end

    it 'GET /admin/player/new should render and create record upon submission' do
      visit new_path(model_name: 'player')

      is_expected.to have_content('Save and edit')
      is_expected.not_to have_content('Delete')

      is_expected.to have_content('Save and add another')
      fill_in 'player[name]', with: 'Jackie Robinson'
      fill_in 'player[number]', with: '42'
      fill_in 'player[position]', with: 'Second baseman'
      click_button 'Save'
      is_expected.not_to have_content('Edit')

      @player = RailsAdmin::AbstractModel.new('Player').first
      expect(@player.name).to eq('Jackie Robinson')
      expect(@player.number).to eq(42)
      expect(@player.position).to eq('Second baseman')
    end
  end

  describe 'with all roles' do
    it 'shows links to all actions' do
      @user.update(roles: %i[admin manage_player])
      @player = FactoryBot.create :player

      visit index_path(model_name: 'player')
      is_expected.to have_css('.show_member_link')
      is_expected.to have_css('.edit_member_link')
      is_expected.to have_css('.delete_member_link')
      is_expected.to have_css('.history_show_member_link')
      is_expected.to have_css('.show_in_app_member_link')

      visit show_path(model_name: 'player', id: @player.id)
      is_expected.to have_content('Show')
      is_expected.to have_content('Edit')
      is_expected.to have_content('Delete')
      is_expected.to have_content('History')
      is_expected.to have_content('Show in app')
    end
  end

  describe 'with create and read player role' do
    before do
      @user.update(roles: %i[admin read_player create_player])
    end

    it 'POST /admin/player/new with unauthorized attribute value should raise access denied' do
      visit new_path(model_name: 'player')
      fill_in 'player[name]', with: 'Jackie Robinson'
      uncheck 'player[suspended]'
      expect { click_button 'Save' }.to raise_error(Pundit::NotAuthorizedError)
    end
  end

  describe 'with update and read player role' do
    before do
      @user.update(roles: %i[admin read_player update_player])
    end

    it 'PUT /admin/player/new with unauthorized attribute value should raise access denied' do
      @player = FactoryBot.create :player
      visit edit_path(model_name: 'player', id: @player.id)
      check 'player[retired]'
      expect { click_button 'Save' }.to raise_error(Pundit::NotAuthorizedError)
    end
  end

  context 'when ApplicationController already has pundit_user' do
    let(:admin) { FactoryBot.create :user, roles: [:admin] }
    before do
      RailsAdmin.config.parent_controller = 'ApplicationController'
      allow_any_instance_of(ApplicationController).to receive(:pundit_user).and_return(admin)
    end

    it 'uses original pundit_user' do
      pending 'no way to dynamically change superclass'
      expect { visit dashboard_path }.not_to raise_error
    end
  end

  context 'when custom authorization key is set' do
    before do
      RailsAdmin.config do |c|
        c.actions do
          dashboard
          index do
            authorization_key :rails_admin_index
          end
        end
      end
    end

    it 'uses the custom key' do
      expect { visit index_path(model_name: 'team') }.not_to raise_error
    end
  end

  context 'when custom authorization key is suffixed with ?' do
    before do
      @user.update(roles: [:admin])
      RailsAdmin.config do |c|
        c.actions do
          dashboard do
            authorization_key :dashboard?
          end
          index
        end
      end
    end

    it 'does not append ? on policy check' do
      expect_any_instance_of(ApplicationPolicy).not_to receive(:'dashboard??')
      visit dashboard_path
    end
  end
end
