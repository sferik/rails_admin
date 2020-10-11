require 'spec_helper'

RSpec.describe 'RailsAdmin CanCanCan Authorization', type: :request do
  class Ability
    include CanCan::Ability
    def initialize(user)
      can :access, :rails_admin if user.roles.include? :admin
      can :read, :dashboard
      if user.roles.include? :test_exception
        can :access, :rails_admin
        can :manage, :all
        can :show_in_app, :all

        can %i[update destroy], Player
        cannot %i[update destroy], Player, retired: true
      else
        can :manage, Player if user.roles.include? :manage_player
        can :read, Player, retired: false if user.roles.include? :read_player
        can :create, Player, suspended: true if user.roles.include? :create_player
        can :update, Player, retired: false if user.roles.include? :update_player
        can :destroy, Player, retired: false if user.roles.include? :destroy_player
        can :history, Player, retired: false if user.roles.include? :history_player
        can :show_in_app, Player, retired: false if user.roles.include? :show_in_app_player
      end
    end
  end

  class AdminAbility
    include CanCan::Ability
    def initialize(user)
      can :access, :rails_admin if user.roles.include? :admin
      can :show_in_app, :all
      can :manage, :all
    end
  end

  subject { page }

  before do
    RailsAdmin.config do |c|
      c.authorize_with(:cancancan)
      c.authenticate_with { warden.authenticate! scope: :user }
      c.current_user_method(&:current_user)
    end
    @player_model = RailsAdmin::AbstractModel.new(Player)
    @user = FactoryBot.create :user
    login_as @user
  end

  describe 'with no roles' do
    before do
      @user.update(roles: [])
    end

    it 'GET /admin should raise CanCan::AccessDenied' do
      expect { visit dashboard_path }.to raise_error(CanCan::AccessDenied)
    end

    it 'GET /admin/player should raise CanCan::AccessDenied' do
      expect { visit index_path(model_name: 'player') }.to raise_error(CanCan::AccessDenied)
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

    it 'GET /admin/player should render successfully but not list retired players and not show new, edit, or delete actions' do
      # ensure :name column to be shown
      RailsAdmin.config Player do
        list do
          field :name
        end
      end
      @players = [
        FactoryBot.create(:player, retired: false),
        FactoryBot.create(:player, retired: true),
      ]

      visit index_path(model_name: 'player')

      is_expected.to have_content(@players[0].name)
      is_expected.not_to have_content(@players[1].name)
      is_expected.not_to have_content('Add new')
      is_expected.to have_css('.show_member_link')
      is_expected.not_to have_css('.edit_member_link')
      is_expected.not_to have_css('.delete_member_link')
      is_expected.not_to have_css('.history_show_member_link')
      is_expected.not_to have_css('.show_in_app_member_link')
    end

    it 'GET /admin/team should raise CanCan::AccessDenied' do
      expect { visit index_path(model_name: 'team') }.to raise_error(CanCan::AccessDenied)
    end

    it 'GET /admin/player/new should raise CanCan::AccessDenied' do
      expect { visit new_path(model_name: 'player') }.to raise_error(CanCan::AccessDenied)
    end
  end

  describe 'with create and read player role' do
    before do
      @user.update(roles: %i[admin read_player create_player])
    end

    it 'GET /admin/player/new should render and create record upon submission' do
      visit new_path(model_name: 'player')

      is_expected.not_to have_content('Save and edit')
      is_expected.not_to have_content('Delete')

      is_expected.to have_content('Save and add another')
      fill_in 'player[name]', with: 'Jackie Robinson'
      fill_in 'player[number]', with: '42'
      fill_in 'player[position]', with: 'Second baseman'
      click_button 'Save' # first(:button, "Save").click
      is_expected.not_to have_content('Edit')

      @player = RailsAdmin::AbstractModel.new('Player').first
      expect(@player.name).to eq('Jackie Robinson')
      expect(@player.number).to eq(42)
      expect(@player.position).to eq('Second baseman')
      expect(@player).to be_suspended # suspended is inherited behavior based on permission
    end

    it 'POST /admin/player/new with unauthorized attribute value should raise access denied' do
      visit new_path(model_name: 'player')
      fill_in 'player[name]', with: 'Jackie Robinson'
      uncheck 'player[suspended]'
      expect { click_button 'Save' }.to raise_error(CanCan::AccessDenied)
    end

    it 'GET /admin/player/1/edit should raise access denied' do
      @player = FactoryBot.create :player
      expect { visit edit_path(model_name: 'player', id: @player.id) }.to raise_error(CanCan::AccessDenied)
    end
  end

  describe 'with update and read player role' do
    before do
      @user.update(roles: %i[admin read_player update_player])
    end

    it 'GET /admin/player/1/edit should render and update record upon submission' do
      @player = FactoryBot.create :player
      visit edit_path(model_name: 'player', id: @player.id)
      is_expected.to have_content('Save and edit')
      is_expected.not_to have_content('Save and add another')
      is_expected.not_to have_content('Add new')
      is_expected.not_to have_content('Delete')
      is_expected.not_to have_content('History')
      is_expected.not_to have_content('Show in app')
      fill_in 'player[name]', with: 'Jackie Robinson'
      click_button 'Save' # click_button "Save" # first(:button, "Save").click
      @player.reload
      expect(@player.name).to eq('Jackie Robinson')
    end

    it 'GET /admin/player/1/edit with retired player should raise access denied' do
      @player = FactoryBot.create :player, retired: true
      expect { visit edit_path(model_name: 'player', id: @player.id) }.to raise_error(CanCan::AccessDenied)
    end

    it 'PUT /admin/player/new with unauthorized attribute value should raise access denied' do
      @player = FactoryBot.create :player
      visit edit_path(model_name: 'player', id: @player.id)
      check 'player[retired]'
      expect { click_button 'Save' }.to raise_error(CanCan::AccessDenied)
    end

    it 'GET /admin/player/1/delete should raise access denied' do
      @player = FactoryBot.create :player
      expect { visit delete_path(model_name: 'player', id: @player.id) }.to raise_error(CanCan::AccessDenied)
    end
  end

  describe 'with history role' do
    it 'shows links to history action' do
      @user.update(roles: %i[admin read_player history_player])
      @player = FactoryBot.create :player

      visit index_path(model_name: 'player')
      is_expected.to have_css('.show_member_link')
      is_expected.not_to have_css('.edit_member_link')
      is_expected.not_to have_css('.delete_member_link')
      is_expected.to have_css('.history_show_member_link')

      visit show_path(model_name: 'player', id: @player.id)
      is_expected.to have_content('Show')
      is_expected.not_to have_content('Edit')
      is_expected.not_to have_content('Delete')
      is_expected.to have_content('History')
    end
  end

  describe 'with show in app role' do
    it 'shows links to show in app action' do
      @user.update(roles: %i[admin read_player show_in_app_player])
      @player = FactoryBot.create :player

      visit index_path(model_name: 'player')
      is_expected.to have_css('.show_member_link')
      is_expected.not_to have_css('.edit_member_link')
      is_expected.not_to have_css('.delete_member_link')
      is_expected.not_to have_css('.history_show_member_link')
      is_expected.to have_css('.show_in_app_member_link')

      visit show_path(model_name: 'player', id: @player.id)
      is_expected.to have_content('Show')
      is_expected.not_to have_content('Edit')
      is_expected.not_to have_content('Delete')
      is_expected.not_to have_content('History')
      is_expected.to have_content('Show in app')
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

  describe 'with destroy and read player role' do
    before do
      @user.update(roles: %i[admin read_player destroy_player])
    end

    it 'GET /admin/player/1/delete should render and destroy record upon submission' do
      @player = FactoryBot.create :player
      player_id = @player.id
      visit delete_path(model_name: 'player', id: player_id)

      click_button "Yes, I'm sure"

      expect(@player_model.get(player_id)).to be_nil
    end

    it 'GET /admin/player/1/delete with retired player should raise access denied' do
      @player = FactoryBot.create :player, retired: true
      expect { visit delete_path(model_name: 'player', id: @player.id) }.to raise_error(CanCan::AccessDenied)
    end

    it 'GET /admin/player/bulk_delete should render records which are authorized to' do
      active_player = FactoryBot.create :player, retired: false
      retired_player = FactoryBot.create :player, retired: true

      post bulk_action_path(bulk_action: 'bulk_delete', model_name: 'player', bulk_ids: [active_player, retired_player].collect(&:id))

      expect(response.body).to include(active_player.name)
      expect(response.body).not_to include(retired_player.name)
    end

    it 'POST /admin/player/bulk_destroy should destroy records which are authorized to' do
      active_player = FactoryBot.create :player, retired: false
      retired_player = FactoryBot.create :player, retired: true

      delete bulk_delete_path(model_name: 'player', bulk_ids: [active_player, retired_player].collect(&:id))
      expect(@player_model.get(active_player.id)).to be_nil
      expect(@player_model.get(retired_player.id)).not_to be_nil
    end
  end

  describe 'with exception role' do
    it 'GET /admin/player/bulk_delete should render records which are authorized to' do
      @user.update(roles: %i[admin test_exception])
      active_player = FactoryBot.create :player, retired: false
      retired_player = FactoryBot.create :player, retired: true

      post bulk_action_path(bulk_action: 'bulk_delete', model_name: 'player', bulk_ids: [active_player, retired_player].collect(&:id))

      expect(response.body).to include(active_player.name)
      expect(response.body).not_to include(retired_player.name)
    end

    it 'POST /admin/player/bulk_destroy should destroy records which are authorized to' do
      @user.update(roles: %i[admin test_exception])
      active_player = FactoryBot.create :player, retired: false
      retired_player = FactoryBot.create :player, retired: true

      delete bulk_delete_path(model_name: 'player', bulk_ids: [active_player, retired_player].collect(&:id))
      expect(@player_model.get(active_player.id)).to be_nil
      expect(@player_model.get(retired_player.id)).not_to be_nil
    end
  end

  describe 'with a custom admin ability' do
    before do
      RailsAdmin.config { |c| c.authorize_with :cancancan, AdminAbility }
      @user = FactoryBot.create :user
      login_as @user
    end

    describe 'with admin role only' do
      before do
        @user.update(roles: [:admin])
      end

      it 'GET /admin/team should render successfully' do
        visit index_path(model_name: 'team')
        expect(page.status_code).to eq(200)
      end

      it 'GET /admin/player/new should render successfully' do
        visit new_path(model_name: 'player')
        expect(page.status_code).to eq(200)
      end

      it 'GET /admin/player/1/edit should render successfully' do
        @player = FactoryBot.create :player
        visit edit_path(model_name: 'player', id: @player.id)
        expect(page.status_code).to eq(200)
      end

      it 'GET /admin/player/1/edit with retired player should render successfully' do
        @player = FactoryBot.create :player, retired: true
        visit edit_path(model_name: 'player', id: @player.id)
        expect(page.status_code).to eq(200)
      end

      it 'GET /admin/player/1/delete should render successfully' do
        @player = FactoryBot.create :player
        visit delete_path(model_name: 'player', id: @player.id)
        expect(page.status_code).to eq(200)
      end

      it 'GET /admin/player/1/delete with retired player should render successfully' do
        @player = FactoryBot.create :player, retired: true
        visit delete_path(model_name: 'player', id: @player.id)
        expect(page.status_code).to eq(200)
      end
    end
  end
end
