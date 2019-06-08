require 'spec_helper'

describe 'RailsAdmin Basic Create', type: :request do
  subject { page }

  describe 'create' do
    before do
      visit new_path(model_name: 'player')
      fill_in 'player[name]', with: 'Jackie Robinson'
      fill_in 'player[number]', with: '42'
      fill_in 'player[position]', with: 'Second baseman'
      click_button 'Save'
      @player = RailsAdmin::AbstractModel.new('Player').first
    end

    it 'creates an object with correct attributes' do
      expect(@player.name).to eq('Jackie Robinson')
      expect(@player.number).to eq(42)
      expect(@player.position).to eq('Second baseman')
    end
  end

  describe 'create and edit' do
    before do
      visit new_path(model_name: 'player')

      fill_in 'player[name]', with: 'Jackie Robinson'
      fill_in 'player[number]', with: '42'
      fill_in 'player[position]', with: 'Second baseman'
      click_button 'Save and edit'

      @player = RailsAdmin::AbstractModel.new('Player').first
    end

    it 'creates an object with correct attributes' do
      expect(@player.name).to eq('Jackie Robinson')
      expect(@player.number).to eq(42)
      expect(@player.position).to eq('Second baseman')
    end
  end

  describe 'create and add another' do
    before do
      visit new_path(model_name: 'player')

      fill_in 'player[name]', with: 'Jackie Robinson'
      fill_in 'player[number]', with: '42'
      fill_in 'player[position]', with: 'Second baseman'
      click_button 'Save and add another'

      @player = RailsAdmin::AbstractModel.new('Player').first
    end

    it 'creates an object with correct attributes' do
      expect(@player.name).to eq('Jackie Robinson')
      expect(@player.number).to eq(42)
      expect(@player.position).to eq('Second baseman')
    end
  end

  describe 'create with has-one association' do
    before do
      @draft = FactoryBot.create :draft

      post new_path(model_name: 'player', player: {name: 'Jackie Robinson', number: 42, position: 'Second baseman', draft_id: @draft.id})

      @player = RailsAdmin::AbstractModel.new('Player').all.to_a.detect { |player| player.name == 'Jackie Robinson' }
    end

    it 'creates an object with correct associations' do
      @draft.reload
      expect(@player.draft).to eq(@draft)
    end
  end

  describe 'create with has-many association' do
    before do
      @divisions = Array.new(3) { Division.create!(name: "div #{Time.now.to_f}", league: League.create!(name: "league #{Time.now.to_f}")) }
      post new_path(model_name: 'league', league: {name: 'National League', division_ids: [@divisions[0].id]})
      @league = RailsAdmin::AbstractModel.new('League').all.to_a.last
    end

    it 'creates an object with correct associations' do
      @divisions[0].reload
      expect(@league.divisions).to include(@divisions[0])
      expect(@league.divisions).not_to include(@divisions[1])
      expect(@league.divisions).not_to include(@divisions[2])
    end
  end

  describe 'create with has-and-belongs-to-many association' do
    before do
      @teams = FactoryBot.create_list(:team, 3)
      post new_path(model_name: 'fan', fan: {name: 'John Doe', team_ids: [@teams[0].id]})
      @fan = RailsAdmin::AbstractModel.new('Fan').first
    end

    it 'creates an object with correct associations' do
      @teams[0].reload
      expect(@fan.teams).to include(@teams[0])
      expect(@fan.teams).not_to include(@teams[1])
      expect(@fan.teams).not_to include(@teams[2])
    end
  end

  describe 'create with has-and-belongs-to-many association which has customized primary/foreign keys' do
    before do
      @authors = FactoryBot.create_list(:author, 3)
      @field_authors = RailsAdmin.config('Book').create.fields.detect { |f| f.name == :authors }
      post new_path(model_name: 'book', book: {title: 'Just A Book', @field_authors.method_name => @authors.collect(&@field_authors.associated_primary_key)})
      @book = RailsAdmin::AbstractModel.new('Book').first
    end

    it 'creates an object with correct associations' do
      expect(@book.title).to eq('Just A Book')
      expect(@book.authors).to eq(@authors)
    end
  end

  describe 'create with uniqueness constraint violated', given: 'a player exists' do
    before do
      @team = FactoryBot.create :team
      @player = FactoryBot.create :player, team: @team

      post new_path(model_name: 'player', player: {name: @player.name, number: @player.number.to_s, position: @player.position, team_id: @team.id})
    end

    it 'shows an error message' do
      expect(response.body).to include('There is already a player with that number on this team')
    end
  end

  describe 'create with invalid object' do
    before do
      post new_path(model_name: 'player', player: {id: 1})
    end

    it 'shows an error message' do
      expect(response.body).to include('Player failed to be created')
    end
  end

  describe 'create with object with errors on base' do
    before do
      visit new_path(model_name: 'player')
      fill_in 'player[name]', with: 'Jackie Robinson on steroids'
      click_button 'Save and add another'
    end

    it 'shows error base error message in flash' do
      is_expected.to have_content('Player failed to be created')
      is_expected.to have_content('Player is cheating')
    end
  end
end
