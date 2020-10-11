# coding: utf-8

require 'spec_helper'

RSpec.describe 'Index action', type: :request do
  subject { page }

  describe 'page' do
    it 'shows "List of Models", should show filters and should show column headers' do
      RailsAdmin.config.default_items_per_page = 1
      2.times { FactoryBot.create :player } # two pages of players
      visit index_path(model_name: 'player')
      is_expected.to have_content('List of Players')
      is_expected.to have_content('Created at')
      is_expected.to have_content('Updated at')

      # it "shows the show, edit and delete links" do
      is_expected.to have_selector("li[title='Show'] a")
      is_expected.to have_selector("li[title='Edit'] a")
      is_expected.to have_selector("li[title='Delete'] a")

      # it "has the search box with some prompt text" do
      is_expected.to have_selector("input[placeholder='Filter']")

      # https://github.com/sferik/rails_admin/issues/362
      # test that no link uses the "wildcard route" with the main
      # controller and list method
      # it "does not use the 'wildcard route'" do
      is_expected.to have_selector("a[href*='all=true']") # make sure we're fully testing pagination
      is_expected.to have_no_selector("a[href^='/rails_admin/main/list']")
    end
  end

  describe 'css hooks' do
    it 'is present' do
      RailsAdmin.config Team do
        list do
          field :name
        end
      end
      FactoryBot.create :team
      visit index_path(model_name: 'team')
      is_expected.to have_selector('th.header.string_type.name_field')
      is_expected.to have_selector('td.string_type.name_field')
    end
  end

  describe 'with querying and filtering' do
    before do
      @teams = Array.new(2) do
        FactoryBot.create(:team)
      end
      @players = [
        FactoryBot.create(:player, retired: true, injured: true, team: @teams[0]),
        FactoryBot.create(:player, retired: true, injured: false, team: @teams[0]),
        FactoryBot.create(:player, retired: false, injured: true, team: @teams[1]),
        FactoryBot.create(:player, retired: false, injured: false, team: @teams[1]),
      ]
      @comment = FactoryBot.create(:comment, commentable: @players[2])
    end

    it 'allows to query on any attribute' do
      RailsAdmin.config Player do
        list do
          field :name
          field :team
          field :injured
          field :retired
        end
      end

      visit index_path(model_name: 'player', query: @players[0].name)
      is_expected.to have_content(@players[0].name)
      (1..3).each do |i|
        is_expected.to have_no_content(@players[i].name)
      end
    end

    it 'allows to filter on one attribute' do
      RailsAdmin.config Player do
        list do
          field :name
          field :team
          field :injured
          field :retired
        end
      end

      visit index_path(model_name: 'player', f: {injured: {'1' => {v: 'true'}}})
      is_expected.to have_content(@players[0].name)
      is_expected.to have_no_content(@players[1].name)
      is_expected.to have_content(@players[2].name)
      is_expected.to have_no_content(@players[3].name)
    end

    it 'allows to combine filters on two different attributes' do
      RailsAdmin.config Player do
        list do
          field :name
          field :team
          field :injured
          field :retired
        end
      end

      visit index_path(model_name: 'player', f: {retired: {'1' => {v: 'true'}}, injured: {'1' => {v: 'true'}}})
      is_expected.to have_content(@players[0].name)
      (1..3).each do |i|
        is_expected.to have_no_content(@players[i].name)
      end
    end

    it 'allows to filter on belongs_to relationships' do
      RailsAdmin.config Player do
        list do
          field :name
          field :team
          field :injured
          field :retired
        end
      end

      visit index_path(model_name: 'player', f: {team: {'1' => {v: @teams[0].name}}})
      is_expected.to have_content(@players[0].name)
      is_expected.to have_content(@players[1].name)
      is_expected.to have_no_content(@players[2].name)
      is_expected.to have_no_content(@players[3].name)
    end

    it 'allows to disable search on attributes' do
      RailsAdmin.config Player do
        list do
          field :position
          field :name do
            searchable false
          end
        end
      end
      visit index_path(model_name: 'player', query: @players[0].name)
      is_expected.to have_no_content(@players[0].name)
    end

    it 'allows to search a belongs_to attribute over the base table' do
      RailsAdmin.config Player do
        list do
          field PK_COLUMN
          field :name
          field :team do
            searchable Player => :team_id
          end
        end
      end
      visit index_path(model_name: 'player', f: {team: {'1' => {v: @teams.first.id}}})
      is_expected.to have_content(@players[0].name)
      is_expected.to have_content(@players[1].name)
      is_expected.to have_no_content(@players[2].name)
      is_expected.to have_no_content(@players[3].name)
    end

    it 'allows to search a belongs_to attribute over the target table' do
      RailsAdmin.config Player do
        list do
          field PK_COLUMN
          field :name
          field :team do
            searchable Team => :name
          end
        end
      end
      visit index_path(model_name: 'player', f: {team: {'1' => {v: @teams.first.name}}})
      is_expected.to have_content(@players[0].name)
      is_expected.to have_content(@players[1].name)
      is_expected.to have_no_content(@players[2].name)
      is_expected.to have_no_content(@players[3].name)
    end

    it 'allows to search a belongs_to attribute over the target table with a table name specified as a hash' do
      RailsAdmin.config Player do
        list do
          field PK_COLUMN
          field :name
          field :team do
            searchable teams: :name
          end
        end
      end
      visit index_path(model_name: 'player', f: {team: {'1' => {v: @teams.first.name}}})
      is_expected.to have_content(@players[0].name)
      is_expected.to have_content(@players[1].name)
      is_expected.to have_no_content(@players[2].name)
      is_expected.to have_no_content(@players[3].name)
    end

    it 'allows to search a belongs_to attribute over the target table with a table name specified as a string' do
      RailsAdmin.config Player do
        list do
          field PK_COLUMN
          field :name
          field :team do
            searchable 'teams.name'
          end
        end
      end
      visit index_path(model_name: 'player', f: {team: {'1' => {v: @teams.first.name}}})
      is_expected.to have_content(@players[0].name)
      is_expected.to have_content(@players[1].name)
      is_expected.to have_no_content(@players[2].name)
      is_expected.to have_no_content(@players[3].name)
    end

    it 'allows to search a belongs_to attribute over the label method by default' do
      RailsAdmin.config Player do
        list do
          field PK_COLUMN
          field :name
          field :team
        end
      end
      visit index_path(model_name: 'player', f: {team: {'1' => {v: @teams.first.name}}})
      is_expected.to have_content(@players[0].name)
      is_expected.to have_content(@players[1].name)
      is_expected.to have_no_content(@players[2].name)
      is_expected.to have_no_content(@players[3].name)
    end

    it 'allows to search a belongs_to attribute over the target table when an attribute is specified' do
      RailsAdmin.config Player do
        list do
          field PK_COLUMN
          field :name
          field :team do
            searchable :name
          end
        end
      end
      visit index_path(model_name: 'player', f: {team: {'1' => {v: @teams.first.name}}})
      is_expected.to have_content(@players[0].name)
      is_expected.to have_content(@players[1].name)
      is_expected.to have_no_content(@players[2].name)
      is_expected.to have_no_content(@players[3].name)
    end

    it 'allows to search over more than one attribute' do
      RailsAdmin.config Player do
        list do
          field PK_COLUMN
          field :name
          field :team do
            searchable [:name, {Player => :team_id}]
          end
        end
      end
      visit index_path(model_name: 'player', f: {team: {'1' => {v: @teams.first.name}, '2' => {v: @teams.first.id, o: 'is'}}})
      is_expected.to have_content(@players[0].name)
      is_expected.to have_content(@players[1].name)
      is_expected.to have_no_content(@players[2].name)
      is_expected.to have_no_content(@players[3].name)
      # same with a different id
      visit index_path(model_name: 'player', f: {team: {'1' => {v: @teams.first.name}, '2' => {v: @teams.last.id, o: 'is'}}})
      is_expected.to have_no_content(@players[0].name)
      is_expected.to have_no_content(@players[1].name)
      is_expected.to have_no_content(@players[2].name)
      is_expected.to have_no_content(@players[3].name)
    end

    it 'allows to search a has_many attribute over the target table' do
      RailsAdmin.config Player do
        list do
          field PK_COLUMN
          field :name
          field :comments do
            searchable :content
          end
        end
      end
      visit index_path(model_name: 'player', f: {comments: {'1' => {v: @comment.content}}})
      is_expected.to have_no_content(@players[0].name)
      is_expected.to have_no_content(@players[1].name)
      is_expected.to have_content(@players[2].name)
      is_expected.to have_no_content(@players[3].name)
    end

    it 'displays base filters when no filters are present in the params' do
      RailsAdmin.config Player do
        list { filters(%i[name team]) }
      end
      visit index_path(model_name: 'player')

      expect(JSON.parse(find('#filters_box')['data-options']).map(&:symbolize_keys)).to match_array [
        {
          index: 1,
          label: 'Name',
          name: 'name',
          type: 'string',
          value: '',
          operator: nil,
        },
        {
          index: 2,
          label: 'Team',
          name: 'team',
          type: 'belongs_to_association',
          value: '',
          operator: nil,
        },
      ]
    end
  end

  describe 'fields' do
    it 'shows all by default' do
      visit index_path(model_name: 'fan')
      expect(all('th').collect(&:text).delete_if { |t| /^\n*$/ =~ t }).
        to match_array ['Id', 'Created at', 'Updated at', 'Their Name', 'Teams']
    end

    it 'hides some fields on demand with a block' do
      RailsAdmin.config Fan do
        list do
          exclude_fields_if do
            type == :datetime
          end
        end
      end
      visit index_path(model_name: 'fan')
      expect(all('th').collect(&:text).delete_if { |t| /^\n*$/ =~ t }).
        to match_array ['Id', 'Their Name', 'Teams']
    end

    it 'hides some fields on demand with fields list' do
      RailsAdmin.config Fan do
        list do
          exclude_fields :created_at, :updated_at
        end
      end
      visit index_path(model_name: 'fan')
      expect(all('th').collect(&:text).delete_if { |t| /^\n*$/ =~ t }).
        to match_array ['Id', 'Their Name', 'Teams']
    end

    it 'adds some fields on demand with a block' do
      RailsAdmin.config Fan do
        list do
          include_fields_if do
            type != :datetime
          end
        end
      end
      visit index_path(model_name: 'fan')
      expect(all('th').collect(&:text).delete_if { |t| /^\n*$/ =~ t }).
        to match_array ['Id', 'Their Name', 'Teams']
    end

    it 'shows some fields on demand with fields list, respect ordering and configure them' do
      RailsAdmin.config Fan do
        list do
          fields :name, PK_COLUMN do
            label do
              "Modified #{label}"
            end
          end
        end
      end
      visit index_path(model_name: 'fan')
      expect(all('th').collect(&:text).delete_if { |t| /^\n*$/ =~ t }).
        to match_array ['Modified Id', 'Modified Their Name']
    end

    it 'shows all fields if asked' do
      RailsAdmin.config Fan do
        list do
          include_all_fields
          field PK_COLUMN
          field :name
        end
      end
      visit index_path(model_name: 'fan')
      expect(all('th').collect(&:text).delete_if { |t| /^\n*$/ =~ t }).
        to match_array ['Id', 'Created at', 'Updated at', 'Their Name', 'Teams']
    end

    it 'appears in order defined' do
      RailsAdmin.config Fan do
        list do
          field :updated_at
          field :name
          field PK_COLUMN
          field :created_at
        end
      end
      visit index_path(model_name: 'fan')
      expect(all('th').collect(&:text).delete_if { |t| /^\n*$/ =~ t }).
        to eq(['Updated at', 'Their Name', 'Id', 'Created at'])
    end

    it 'only lists the defined fields if some fields are defined' do
      RailsAdmin.config Fan do
        list do
          field PK_COLUMN
          field :name
        end
      end
      visit index_path(model_name: 'fan')
      expect(all('th').collect(&:text).delete_if { |t| /^\n*$/ =~ t }).
        to eq(['Id', 'Their Name'])
      is_expected.to have_no_selector('th:nth-child(4).header')
    end

    it 'delegates the label option to the ActiveModel API' do
      RailsAdmin.config Fan do
        list do
          field :name
        end
      end
      visit index_path(model_name: 'fan')
      expect(find('th:nth-child(2)')).to have_content('Their Name')
    end

    it 'is renameable' do
      RailsAdmin.config Fan do
        list do
          field PK_COLUMN do
            label 'Identifier'
          end
          field :name
        end
      end
      visit index_path(model_name: 'fan')
      expect(find('th:nth-child(2)')).to have_content('Identifier')
      expect(find('th:nth-child(3)')).to have_content('Their Name')
    end

    it 'is renameable by type' do
      RailsAdmin.config Fan do
        list do
          fields_of_type :datetime do
            label { "#{label} (datetime)" }
          end
        end
      end
      visit index_path(model_name: 'fan')
      expect(all('th').collect(&:text).delete_if { |t| /^\n*$/ =~ t }).
        to match_array ['Id', 'Created at (datetime)', 'Updated at (datetime)', 'Their Name', 'Teams']
    end

    it 'is globally renameable by type' do
      RailsAdmin.config Fan do
        list do
          fields_of_type :datetime do
            label { "#{label} (datetime)" }
          end
        end
      end
      visit index_path(model_name: 'fan')
      expect(all('th').collect(&:text).delete_if { |t| /^\n*$/ =~ t }).
        to match_array ['Id', 'Created at (datetime)', 'Updated at (datetime)', 'Their Name', 'Teams']
    end

    it 'is sortable by default' do
      visit index_path(model_name: 'fan')
      is_expected.to have_selector('th:nth-child(2).header')
      is_expected.to have_selector('th:nth-child(3).header')
      is_expected.to have_selector('th:nth-child(4).header')
      is_expected.to have_selector('th:nth-child(5).header')
    end

    it 'has option to disable sortability' do
      RailsAdmin.config Fan do
        list do
          field PK_COLUMN do
            sortable false
          end
          field :name
        end
      end
      visit index_path(model_name: 'fan')
      is_expected.to have_no_selector('th:nth-child(2).header')
      is_expected.to have_selector('th:nth-child(3).header')
    end

    it 'has option to disable sortability by type' do
      RailsAdmin.config Fan do
        list do
          fields_of_type :datetime do
            sortable false
          end
          field PK_COLUMN
          field :name
          field :created_at
          field :updated_at
        end
      end
      visit index_path(model_name: 'fan')
      is_expected.to have_selector('th:nth-child(2).header')
      is_expected.to have_selector('th:nth-child(3).header')
      is_expected.to have_no_selector('th:nth-child(4).header')
      is_expected.to have_no_selector('th:nth-child(5).header')
    end

    it 'has option to disable sortability by type globally' do
      RailsAdmin.config Fan do
        list do
          fields_of_type :datetime do
            sortable false
          end
          field PK_COLUMN
          field :name
          field :created_at
          field :updated_at
        end
      end
      visit index_path(model_name: 'fan')
      is_expected.to have_selector('th:nth-child(2).header')
      is_expected.to have_selector('th:nth-child(3).header')
      is_expected.to have_no_selector('th:nth-child(4).header')
      is_expected.to have_no_selector('th:nth-child(5).header')
    end

    it 'has option to hide fields by type' do
      RailsAdmin.config Fan do
        list do
          fields_of_type :datetime do
            hide
          end
        end
      end
      visit index_path(model_name: 'fan')
      expect(all('th').collect(&:text).delete_if { |t| /^\n*$/ =~ t }).
        to match_array ['Id', 'Their Name', 'Teams']
    end

    it 'has option to hide fields by type globally' do
      RailsAdmin.config Fan do
        list do
          fields_of_type :datetime do
            hide
          end
        end
      end
      visit index_path(model_name: 'fan')
      expect(all('th').collect(&:text).delete_if { |t| /^\n*$/ =~ t }).
        to match_array ['Id', 'Their Name', 'Teams']
    end

    it 'has option to customize column width' do
      RailsAdmin.config Fan do
        list do
          field PK_COLUMN do
            column_width 200
          end
          field :name
          field :created_at
          field :updated_at
        end
      end
      @fans = FactoryBot.create_list(:fan, 2)
      visit index_path(model_name: 'fan')
      # NOTE: Capybara really doesn't want us to look at invisible text. This test
      # could break at any moment.
      expect(find('style').native.text).to include("#list th.#{PK_COLUMN}_field")
      expect(find('style').native.text).to include("#list td.#{PK_COLUMN}_field")
    end

    it 'has option to customize output formatting' do
      RailsAdmin.config Fan do
        list do
          field PK_COLUMN
          field :name do
            formatted_value do
              value.to_s.upcase
            end
          end
          field :created_at
          field :updated_at
        end
      end
      @fans = FactoryBot.create_list(:fan, 2).sort_by(&:id)
      visit index_path(model_name: 'fan')
      expect(find('tbody tr:nth-child(1) td:nth-child(3)')).to have_content(@fans[1].name.upcase)
      expect(find('tbody tr:nth-child(2) td:nth-child(3)')).to have_content(@fans[0].name.upcase)
    end

    it 'has a simple option to customize output formatting of date fields' do
      RailsAdmin.config Fan do
        list do
          field PK_COLUMN
          field :name
          field :created_at do
            date_format :short
          end
          field :updated_at
        end
      end
      @fans = FactoryBot.create_list(:fan, 2)
      visit index_path(model_name: 'fan')
      is_expected.to have_selector('tbody tr:nth-child(1) td:nth-child(4)', text: /\d{2} \w{3} \d{1,2}:\d{1,2}/)
    end

    it 'has option to customize output formatting of date fields' do
      RailsAdmin.config Fan do
        list do
          field PK_COLUMN
          field :name
          field :created_at do
            strftime_format '%Y-%m-%d'
          end
          field :updated_at
        end
      end
      @fans = FactoryBot.create_list(:fan, 2)
      visit index_path(model_name: 'fan')
      is_expected.to have_selector('tbody tr:nth-child(1) td:nth-child(4)', text: /\d{4}-\d{2}-\d{2}/)
    end

    it 'allows addition of virtual fields (object methods)' do
      RailsAdmin.config Team do
        list do
          field PK_COLUMN
          field :name
          field :player_names_truncated
        end
      end
      @team = FactoryBot.create :team
      @players = FactoryBot.create_list :player, 2, team: @team
      visit index_path(model_name: 'team')
      expect(find('tbody tr:nth-child(1) td:nth-child(4)')).to have_content(@players.sort_by(&:id).collect(&:name).join(', '))
    end
  end

  context 'without pagination' do
    before do
      @players = FactoryBot.create_list(:player, 2)
      visit index_path(model_name: 'player')
    end

    it 'shows "2 results"' do
      is_expected.to have_content('2 players')
    end
  end

  context 'with pagination' do
    def visit_page(page)
      visit index_path(model_name: 'player', page: page)
    end

    before do
      FactoryBot.create_list :player, 3
    end

    describe 'with limited_pagination=false' do
      before { RailsAdmin.config.default_items_per_page = 1 }

      it 'page 1' do
        visit_page(1)

        within('ul.pagination') do
          expect(find('li:first')).to have_content('« Prev')
          expect(find('li:last')).to have_content('Next »')
          expect(find('li.active')).to have_content('1')
        end
      end

      it 'page 2' do
        visit_page(2)

        within('ul.pagination') do
          expect(find('li:first')).to have_content('« Prev')
          expect(find('li:last')).to have_content('Next »')
          expect(find('li.active')).to have_content('2')
        end
      end

      it 'page 3' do
        visit_page(3)

        within('ul.pagination') do
          expect(find('li:first')).to have_content('« Prev')
          expect(find('li:last')).to have_content('Next »')
          expect(find('li.active')).to have_content('3')
        end
      end
    end

    context 'with limited_pagination=true' do
      before do
        RailsAdmin.config.default_items_per_page = 1
        allow(RailsAdmin::AbstractModel.new(Player).config.list).
          to receive(:limited_pagination).
          and_return(true)
      end

      it 'page 1' do
        visit_page(1)

        within('ul.pagination') do
          expect(find('li:first')).not_to have_content('« Prev')
          expect(find('li:last')).to have_content('Next »')
        end
      end

      it 'page 2' do
        visit_page(2)

        within('ul.pagination') do
          expect(find('li:first')).to have_content('« Prev')
          expect(find('li:last')).to have_content('Next »')
        end
      end

      it 'page 3' do
        visit_page(3)

        within('ul.pagination') do
          expect(find('li:first')).to have_content('« Prev')
          expect(find('li:last')).to have_content('Next »')
        end
      end
    end

    describe 'number of items per page' do
      before do
        FactoryBot.create_list :league, 2
      end

      it 'is configurable per model' do
        RailsAdmin.config League do
          list do
            items_per_page 1
          end
        end
        visit index_path(model_name: 'league')
        is_expected.to have_selector('tbody tr', count: 1)
        visit index_path(model_name: 'player')
        is_expected.to have_selector('tbody tr', count: 3)
      end
    end
  end

  context 'on showing all' do
    it 'responds successfully with a single model' do
      FactoryBot.create :player
      visit index_path(model_name: 'player', all: true)
      expect(find('div.total-count')).to have_content('1 player')
      expect(find('div.total-count')).not_to have_content('1 players')
    end

    it 'responds successfully with multiple models' do
      FactoryBot.create_list(:player, 2)
      visit index_path(model_name: 'player', all: true)
      expect(find('div.total-count')).to have_content('2 players')
    end
  end

  context 'with pagination disabled by :associated_collection' do
    it 'responds successfully' do
      @team = FactoryBot.create :team
      Array.new(2) { FactoryBot.create :player, team: @team }
      visit index_path(model_name: 'player', associated_collection: 'players', compact: true, current_action: 'update', source_abstract_model: 'team', source_object_id: @team.id)
      expect(find('div.total-count')).to have_content('2 players')
    end
  end

  describe 'sorting' do
    let(:today) { Date.today }
    let(:players) do
      [{name: 'Jackie Robinson',  created_at: today,            team_id: rand(99_999), number: 42},
       {name: 'Deibinson Romero', created_at: (today - 2.days), team_id: rand(99_999), number: 13},
       {name: 'Sandy Koufax',     created_at: (today - 1.days), team_id: rand(99_999), number: 32}]
    end
    let(:leagues) do
      [{name: 'American',      created_at: (today - 1.day)},
       {name: 'Florida State', created_at: (today - 2.days)},
       {name: 'National',      created_at: today}]
    end
    let(:player_names_by_date) { players.sort_by { |p| p[:created_at] }.collect { |p| p[:name] } }
    let(:league_names_by_date) { leagues.sort_by { |l| l[:created_at] }.collect { |l| l[:name] } }

    before { @players = players.collect { |h| Player.create(h) } }

    it 'is configurable per model' do
      RailsAdmin.config Player do
        list do
          sort_by :created_at
          sort_reverse true
          field :name
        end
      end
      visit index_path(model_name: 'player')
      player_names_by_date.reverse.each_with_index do |name, i|
        expect(find("tbody tr:nth-child(#{i + 1})")).to have_content(name)
      end
    end

    it 'has reverse direction by default' do
      RailsAdmin.config Player do
        list do
          sort_by :created_at
          field :name
        end
      end
      visit index_path(model_name: 'player')
      player_names_by_date.reverse.each_with_index do |name, i|
        expect(find("tbody tr:nth-child(#{i + 1})")).to have_content(name)
      end
    end

    it 'allows change default direction' do
      RailsAdmin.config Player do
        list do
          sort_by :created_at
          sort_reverse false
          field :name
        end
      end
      visit index_path(model_name: 'player')
      player_names_by_date.each_with_index do |name, i|
        expect(find("tbody tr:nth-child(#{i + 1})")).to have_content(name)
      end
    end
  end

  context 'on listing as compact json' do
    it 'has_content an array with 2 elements and contain an array of elements with keys id and label' do
      FactoryBot.create_list(:player, 2)
      get index_path(model_name: 'player', compact: true, format: :json)
      expect(ActiveSupport::JSON.decode(response.body).length).to eq(2)
      ActiveSupport::JSON.decode(response.body).each do |object|
        expect(object).to have_key('id')
        expect(object).to have_key('label')
      end
    end
  end

  describe 'with search operator' do
    let(:player) { FactoryBot.create :player }

    before do
      expect(Player.count).to eq(0)
    end

    it 'finds the player if the query matches the default search operator' do
      RailsAdmin.config do |config|
        config.default_search_operator = 'ends_with'
        config.model Player do
          list { field :name }
        end
      end
      visit index_path(model_name: 'player', query: player.name[2, -1])
      is_expected.to have_content(player.name)
    end

    it 'does not find the player if the query does not match the default search operator' do
      RailsAdmin.config do |config|
        config.default_search_operator = 'ends_with'
        config.model Player do
          list { field :name }
        end
      end
      visit index_path(model_name: 'player', query: player.name[0, 2])
      is_expected.to have_no_content(player.name)
    end

    it 'finds the player if the query matches the specified search operator' do
      RailsAdmin.config Player do
        list do
          field :name do
            search_operator 'starts_with'
          end
        end
      end
      visit index_path(model_name: 'player', query: player.name[0, 2])
      is_expected.to have_content(player.name)
    end

    it 'does not find the player if the query does not match the specified search operator' do
      RailsAdmin.config Player do
        list do
          field :name do
            search_operator 'starts_with'
          end
        end
      end
      visit index_path(model_name: 'player', query: player.name[1..-1])
      is_expected.to have_no_content(player.name)
    end
  end

  describe 'with custom search' do
    before do
      RailsAdmin.config do |config|
        config.model Player do
          list do
            search_by :rails_admin_search
          end
        end
      end
    end
    let!(:players) do
      [FactoryBot.create(:player, name: 'Joe'),
       FactoryBot.create(:player, name: 'George')]
    end

    it 'performs search using given scope' do
      visit index_path(model_name: 'player', query: 'eoJ')
      is_expected.to have_content(players[0].name)
      is_expected.to have_no_content(players[1].name)
    end
  end

  context 'with overridden to_param' do
    before do
      @ball = FactoryBot.create :ball

      visit index_path(model_name: 'ball')
    end

    it 'shows the show, edit and delete links with valid url' do
      is_expected.to have_selector("td a[href$='/admin/ball/#{@ball.id}']")
      is_expected.to have_selector("td a[href$='/admin/ball/#{@ball.id}/edit']")
      is_expected.to have_selector("td a[href$='/admin/ball/#{@ball.id}/delete']")
    end
  end

  describe 'with scopes' do
    before do
      RailsAdmin.config do |config|
        config.model Team do
          list do
            scopes [nil, :red, :white]
          end
        end
      end
      @teams = [
        FactoryBot.create(:team, color: 'red'),
        FactoryBot.create(:team, color: 'red'),
        FactoryBot.create(:team, color: 'white'),
        FactoryBot.create(:team, color: 'black'),
      ]
    end

    it 'displays configured scopes' do
      visit index_path(model_name: 'team')
      expect(find('#scope_selector li:first')).to have_content('All')
      expect(find('#scope_selector li:nth-child(2)')).to have_content('Red')
      expect(find('#scope_selector li:nth-child(3)')).to have_content('White')
      expect(find('#scope_selector li:last')).to have_content('White')
      expect(find('#scope_selector li.active')).to have_content('All')
    end

    it 'shows only scoped records' do
      visit index_path(model_name: 'team')
      is_expected.to have_content(@teams[0].name)
      is_expected.to have_content(@teams[1].name)
      is_expected.to have_content(@teams[2].name)
      is_expected.to have_content(@teams[3].name)

      visit index_path(model_name: 'team', scope: 'red')
      expect(find('#scope_selector li.active')).to have_content('Red')
      is_expected.to have_content(@teams[0].name)
      is_expected.to have_content(@teams[1].name)
      is_expected.to have_no_content(@teams[2].name)
      is_expected.to have_no_content(@teams[3].name)

      visit index_path(model_name: 'team', scope: 'white')
      expect(find('#scope_selector li.active')).to have_content('White')
      is_expected.to have_no_content(@teams[0].name)
      is_expected.to have_no_content(@teams[1].name)
      is_expected.to have_content(@teams[2].name)
      is_expected.to have_no_content(@teams[3].name)
    end

    it 'shows all records instead when scope not in list' do
      visit index_path(model_name: 'team', scope: 'green')
      is_expected.to have_content(@teams[0].name)
      is_expected.to have_content(@teams[1].name)
      is_expected.to have_content(@teams[2].name)
      is_expected.to have_content(@teams[3].name)
    end

    describe 'i18n' do
      before :each do
        en = {admin: {scopes: {
          _all: 'every',
          red: 'krasnyj',
        }}}
        I18n.backend.store_translations(:en, en)
      end
      after { I18n.reload! }

      context 'global' do
        it 'displays configured scopes' do
          visit index_path(model_name: 'team')
          expect(find('#scope_selector li:first')).to have_content('every')
          expect(find('#scope_selector li:nth-child(2)')).to have_content('krasnyj')
          expect(find('#scope_selector li:nth-child(3)')).to have_content('White')
          expect(find('#scope_selector li:last')).to have_content('White')
          expect(find('#scope_selector li.active')).to have_content('every')
        end
      end

      context 'per model' do
        before :each do
          en = {admin: {scopes: {team: {
            _all: 'any',
            red: 'kr',
          }}}}
          I18n.backend.store_translations(:en, en)
        end
        after { I18n.reload! }

        it 'displays configured scopes' do
          visit index_path(model_name: 'team')
          expect(find('#scope_selector li:first')).to have_content('any')
          expect(find('#scope_selector li:nth-child(2)')).to have_content('kr')
          expect(find('#scope_selector li:nth-child(3)')).to have_content('White')
          expect(find('#scope_selector li:last')).to have_content('White')
          expect(find('#scope_selector li.active')).to have_content('any')
        end
      end
    end
  end

  describe 'row CSS class' do
    before do
      RailsAdmin.config do |config|
        config.model Team do
          list do
            row_css_class { 'my_class' }
          end
        end
      end
      @teams = [
        FactoryBot.create(:team, color: 'red'),
        FactoryBot.create(:team, color: 'red'),
        FactoryBot.create(:team, color: 'white'),
        FactoryBot.create(:team, color: 'black'),
      ]
    end

    it 'appends the CSS class to the model row class' do
      visit index_path(model_name: 'team')
      expect(page).to have_css('tr.team_row.my_class')
    end
  end

  describe 'checkboxes?' do
    describe 'default is enabled' do
      before do
        RailsAdmin.config FieldTest do
          list
        end
      end

      it 'displays checkboxes on index' do
        @records = FactoryBot.create_list :field_test, 3

        visit index_path(model_name: 'field_test')
        checkboxes = all(:xpath, './/form[@id="bulk_form"]//input[@type="checkbox"]')
        expect(checkboxes.length).to be > 0

        expect(page).to have_content('Selected items')
      end
    end

    describe 'false' do
      before do
        RailsAdmin.config FieldTest do
          list do
            checkboxes false
          end
        end
      end

      it 'does not display any checkboxes on index' do
        @records = FactoryBot.create_list :field_test, 3

        visit index_path(model_name: 'field_test')
        checkboxes = all(:xpath, './/form[@id="bulk_form"]//input[@type="checkbox"]')
        expect(checkboxes.length).to eq 0

        expect(page).not_to have_content('Selected items')
      end
    end
  end

  describe 'sidescroll' do
    all_team_columns = ['', '', 'Id', 'Created at', 'Updated at', 'Division', 'Name', 'Logo url', 'Team Manager', 'Ballpark', 'Mascot', 'Founded', 'Wins', 'Losses', 'Win percentage', 'Revenue', 'Color', 'Custom field', 'Main Sponsor', 'Players', 'Some Fans', 'Comments']

    it 'displays all fields on one page when true' do
      RailsAdmin.config do |config|
        config.sidescroll = true
      end
      FactoryBot.create_list :team, 3
      visit index_path(model_name: 'team')
      cols = all('th').collect(&:text)
      expect(cols[0..4]).to eq(all_team_columns[0..4])
      expect(cols).to contain_exactly(*all_team_columns)
      expect(page).to have_selector('.ra-sidescroll[data-ra-sidescroll=3]')
    end

    it 'displays all fields with custom frozen columns' do
      RailsAdmin.config do |config|
        config.sidescroll = {num_frozen_columns: 2}
      end
      FactoryBot.create_list :team, 3
      visit index_path(model_name: 'team')
      cols = all('th').collect(&:text)
      expect(cols[0..4]).to eq(all_team_columns[0..4])
      expect(cols).to contain_exactly(*all_team_columns)
      expect(page).to have_selector('.ra-sidescroll[data-ra-sidescroll=2]')
    end

    it 'displays all fields with no checkboxes' do
      RailsAdmin.config do |config|
        config.sidescroll = true
      end
      RailsAdmin.config Team do
        list do
          checkboxes false
        end
      end
      FactoryBot.create_list :team, 3
      visit index_path(model_name: 'team')
      cols = all('th').collect(&:text)
      expect(cols[0..3]).to eq(all_team_columns[1..4])
      expect(cols).to contain_exactly(*all_team_columns[1..-1])
      expect(page).to have_selector('.ra-sidescroll[data-ra-sidescroll=2]')
    end

    it 'displays all fields with no frozen columns' do
      RailsAdmin.config do |config|
        config.sidescroll = {num_frozen_columns: 0}
      end
      FactoryBot.create_list :team, 3
      visit index_path(model_name: 'team')
      cols = all('th').collect(&:text)
      expect(cols[0..4]).to eq(all_team_columns[0..4])
      expect(cols).to contain_exactly(*all_team_columns)
      expect(page).to have_selector('.ra-sidescroll[data-ra-sidescroll=0]')
    end

    it 'displays sets when not set' do
      visit index_path(model_name: 'team')
      expect(all('th').collect(&:text)).to eq ['', 'Id', 'Created at', 'Updated at', 'Division', 'Name', 'Logo url', '...', '']
      expect(page).not_to have_selector('.ra-sidescroll')
    end

    it 'displays sets when global config is on but model config is off' do
      RailsAdmin.config do |config|
        config.sidescroll = true
      end
      RailsAdmin.config Team do
        list do
          sidescroll false
        end
      end
      visit index_path(model_name: 'team')
      expect(all('th').collect(&:text)).to eq ['', 'Id', 'Created at', 'Updated at', 'Division', 'Name', 'Logo url', '...', '']
      expect(page).not_to have_selector('.ra-sidescroll')
    end

    it 'displays all fields when global config is off but model config is on' do
      RailsAdmin.config Team do
        list do
          sidescroll true
        end
      end
      FactoryBot.create_list :team, 3
      visit index_path(model_name: 'team')
      cols = all('th').collect(&:text)
      expect(cols[0..4]).to eq(all_team_columns[0..4])
      expect(cols).to contain_exactly(*all_team_columns)
      expect(page).to have_selector('.ra-sidescroll[data-ra-sidescroll=3]')
    end

    it 'displays all fields with custom model config settings' do
      RailsAdmin.config do |config|
        config.sidescroll = true
      end
      RailsAdmin.config Team do
        list do
          sidescroll(num_frozen_columns: 2)
        end
      end
      FactoryBot.create_list :team, 3
      FactoryBot.create_list :player, 3
      visit index_path(model_name: 'team')
      cols = all('th').collect(&:text)
      expect(cols[0..4]).to eq(all_team_columns[0..4])
      expect(cols).to contain_exactly(*all_team_columns)
      expect(page).to have_selector('.ra-sidescroll[data-ra-sidescroll=2]')
      visit index_path(model_name: 'player')
      expect(page).to have_selector('.ra-sidescroll[data-ra-sidescroll=3]')
    end

    it 'displays all fields with model config checkbox settings' do
      RailsAdmin.config do |config|
        config.sidescroll = true
      end
      RailsAdmin.config Team do
        list do
          sidescroll(num_frozen_columns: 3)
          checkboxes false
        end
      end
      FactoryBot.create_list :team, 3
      visit index_path(model_name: 'team')
      cols = all('th').collect(&:text)
      expect(cols[0..3]).to eq(all_team_columns[1..4])
      expect(cols).to contain_exactly(*all_team_columns[1..-1])
      expect(page).to have_selector('.ra-sidescroll[data-ra-sidescroll=3]')
    end
  end
end
