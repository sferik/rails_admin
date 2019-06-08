require 'spec_helper'

describe 'RailsAdmin Basic Edit', type: :request do
  subject { page }

  describe 'edit' do
    before do
      @player = FactoryBot.create :player
      visit edit_path(model_name: 'player', id: @player.id)
    end

    it "shows \"Edit model\"" do
      is_expected.to have_content('Edit Player')
    end

    it "shows required fields as \"Required\"" do
      is_expected.to have_selector('div', text: /Name\s*Required/)
      is_expected.to have_selector('div', text: /Number\s*Required/)
    end

    it "shows non-required fields as \"Optional\"" do
      expect(find('#player_position_field .help-block')).to have_content('Optional')
      expect(find('#player_born_on_field .help-block')).to have_content('Optional')
      expect(find('#player_notes_field .help-block')).to have_content('Optional')
    end

    it 'checks required fields to have required attribute set' do
      expect(find_field('player_name')[:required]).to be_present
      expect(find_field('player_number')[:required]).to be_present
    end

    it 'checks optional fields to not have required attribute set' do
      expect(find_field('player_position')[:required]).to be_blank
    end
  end

  describe 'association with inverse_of option' do
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

  describe 'readonly associations' do
    it 'is not editable' do
      @league = FactoryBot.create :league
      visit edit_path(model_name: 'league', id: @league.id)
      is_expected.not_to have_selector('select#league_team_ids')
      is_expected.to have_selector('select#league_division_ids') # decoy, fails if naming scheme changes
    end
  end

  describe 'has many associations through more than one association' do
    it 'is not editable' do
      @league = FactoryBot.create :league
      visit edit_path(model_name: 'league', id: @league.id)
      expect(page).to have_selector('select#league_division_ids')
      expect(page).to_not have_selector('select#league_player_ids')
    end
  end

  describe 'edit with has-and-belongs-to-many association' do
    before do
      @teams = FactoryBot.create_list(:team, 3)
      @fan = FactoryBot.create :fan, teams: [@teams[0]]
      visit edit_path(model_name: 'fan', id: @fan.id)
    end

    it 'shows associated objects' do
      is_expected.to have_selector '#fan_team_ids' do |select|
        options = select.all 'option'

        expect(options[0]['selected']).to eq 'selected'
        expect(options[1]['selected']).to eq nil
        expect(options[2]['selected']).to eq nil
      end
    end
  end

  describe 'edit with has-and-belongs-to-many association which has customized primary/foreign keys' do
    before do
      @authors = FactoryBot.create_list(:author, 3)
      @field_authors = RailsAdmin.config('Book').create.fields.detect { |f| f.name == :authors }
      @book = FactoryBot.create :book, @field_authors.method_name => @authors.collect(&@field_authors.associated_primary_key)
      visit edit_path(model_name: 'book', id: @book.id)
    end

    it 'shows associated objects' do
      is_expected.to have_selector "#book_#{@field_authors.method_name}" do |select|
        options = select.all 'option'
        primary_key = @field_authors.associated_primary_key

        expect(options[0]['selected']).to eq 'selected'
        expect(options[1]['selected']).to eq 'selected'
        expect(options[2]['selected']).to eq 'selected'
        expect(options[0]['value']).to eq @authors[0][primary_key].to_s
        expect(options[1]['value']).to eq @authors[1][primary_key].to_s
        expect(options[2]['value']).to eq @authors[2][primary_key].to_s
      end
    end
  end

  describe 'edit with missing object' do
    before do
      visit edit_path(model_name: 'player', id: 1)
    end

    it 'raises NotFound' do
      expect(page.driver.status_code).to eq(404)
    end
  end

  describe 'edit with missing label', given: ['a player exists', 'three teams with no name exist'] do
    before do
      @player = FactoryBot.create :player
      @teams = Array.new(3) { FactoryBot.create :team, name: '' }
      visit edit_path(model_name: 'player', id: @player.id)
    end
  end

  describe 'edit object with overridden to_param' do
    before do
      @ball = FactoryBot.create :ball
      visit edit_path(model_name: 'ball', id: @ball.id)
    end

    it 'displays a link to the delete page' do
      is_expected.to have_selector "a[href$='/admin/ball/#{@ball.id}/delete']"
    end
  end

  describe 'clicking cancel when editing an object' do
    before do
      @ball = FactoryBot.create :ball
      visit '/admin/ball?sort=color'
      click_link 'Edit'
    end

    it "shows cancel button with 'novalidate' attribute" do
      expect(page).to have_css '[type="submit"][name="_continue"][formnovalidate]'
    end

    it 'sends back to previous URL' do
      click_button 'Cancel'
      expect(page.current_url).to eq('http://www.example.com/admin/ball?sort=color')
    end
  end

  describe 'clicking save without changing anything' do
    before { @datetime = 'October 08, 2015 06:45' }
    context 'when config.time_zone set' do
      before do
        RailsAdmin.config Player do
          field :datetime_field
        end
        @old_timezone = Time.zone
        Time.zone = ActiveSupport::TimeZone.new('Central Time (US & Canada)')
      end

      after do
        Time.zone = @old_timezone
      end

      it 'does not alter datetime fields' do
        visit new_path(model_name: 'field_test')
        find('#field_test_datetime_field').set(@datetime)
        click_button 'Save and edit'
        expect(find('#field_test_datetime_field').value).to eq(@datetime)
      end
    end

    context 'without config.time_zone set (default)' do
      it 'does not alter datetime fields' do
        visit new_path(model_name: 'field_test')
        find('#field_test_datetime_field').set(@datetime)
        click_button 'Save and edit'
        expect(find('#field_test_datetime_field').value).to eq(@datetime)
      end
    end
  end
end
