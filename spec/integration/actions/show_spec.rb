require 'spec_helper'

RSpec.describe 'Show action', type: :request do
  subject { page }
  let(:team) { FactoryBot.create :team }

  describe 'page' do
    it 'has History, Edit, Delete, Details and attributes' do
      @player = FactoryBot.create :player
      visit show_path(model_name: 'player', id: @player.id)

      is_expected.to have_selector('a', text: 'History')
      is_expected.to have_selector('a', text: 'Edit')
      is_expected.to have_selector('a', text: 'Delete')
      is_expected.to have_content('Details')
      is_expected.to have_content('Name')
      is_expected.to have_content(@player.name)
      is_expected.to have_content('Number')
      is_expected.to have_content(@player.number)
    end
  end

  context 'with invalid id' do
    it 'raises NotFound' do
      visit '/admin/players/123this-id-doesnt-exist'
      expect(page.driver.status_code).to eq(404)
    end
  end

  describe 'JSON show view' do
    before do
      @player = FactoryBot.create :player
      visit uri
    end

    let(:uri) { show_path(model_name: 'player', id: @player.id, format: :json) }
    let(:body) { page.body }

    it 'creates a JSON uri' do
      expect(uri).to eq("/admin/player/#{@player.id}.json")
    end

    it 'contains the JSONified object' do
      expect(JSON.parse(body)).to eq JSON.parse @player.reload.to_json
    end
  end

  context 'when compact_show_view is enabled' do
    it 'hides nil fields in show view by default' do
      visit show_path(model_name: 'team', id: team.id)
      is_expected.not_to have_css('.logo_url_field')
    end

    it 'hides blank fields in show view by default' do
      team.update logo_url: ''
      visit show_path(model_name: 'team', id: team.id)
      is_expected.not_to have_css('.logo_url_field')
    end

    it 'is disactivable' do
      RailsAdmin.config do |c|
        c.compact_show_view = false
      end

      visit show_path(model_name: 'team', id: team.id)
      is_expected.to have_css('.logo_url_field')
    end

    describe 'with boolean field' do
      let(:player) { FactoryBot.create :player, retired: false }

      it 'does not hide false value' do
        visit show_path(model_name: 'player', id: player.id)
        is_expected.to have_css('.retired_field')
      end
    end
  end

  context 'when compact_show_view is disabled' do
    before do
      RailsAdmin.config do |c|
        c.compact_show_view = false
      end
    end

    it 'shows nil fields' do
      team.update logo_url: nil
      visit show_path(model_name: 'team', id: team.id)
      is_expected.to have_css('.logo_url_field')
    end

    it 'shows blank fields' do
      team.update logo_url: ''
      visit show_path(model_name: 'team', id: team.id)
      is_expected.to have_css('.logo_url_field')
    end
  end

  describe 'bindings' do
    it 'should be present' do
      RailsAdmin.config Team do |_c|
        show do
          field :name do
            show do
              bindings[:object] && bindings[:view] && bindings[:controller]
            end
          end
        end
      end

      visit show_path(model_name: 'team', id: team.id)

      is_expected.to have_selector('dt .name_field.string_type')
    end
  end

  describe 'css hooks' do
    it 'is present' do
      visit show_path(model_name: 'team', id: team.id)

      is_expected.to have_selector('dt .name_field.string_type')
    end
  end

  describe 'field grouping' do
    before do
      RailsAdmin.config do |c|
        c.compact_show_view = false
      end
    end

    it 'is hideable' do
      RailsAdmin.config Team do
        show do
          group :default do
            hide
          end
        end
      end

      visit show_path(model_name: 'team', id: team.id)

      is_expected.not_to have_selector('h4', text: 'Basic info')

      %w[
        division name logo_url manager
        ballpark mascot founded wins
        losses win_percentage revenue
      ].each do |field|
        is_expected.not_to have_selector(".#{field}_field")
      end
    end

    it 'hides association groupings by the name of the association' do
      RailsAdmin.config Team do
        show do
          group :players do
            hide
          end
        end
      end

      visit show_path(model_name: 'team', id: team.id)

      is_expected.not_to have_selector('h4', text: 'Players')
    end

    it 'is renameable' do
      RailsAdmin.config Team do
        show do
          group :default do
            label 'Renamed group'
          end
        end
      end

      visit show_path(model_name: 'team', id: team.id)

      is_expected.to have_selector('h4', text: 'Renamed group')
    end

    it 'has accessor for its fields' do
      RailsAdmin.config Team do
        show do
          group :default do
            field :name
            field :logo_url
          end
          group :belongs_to_associations do
            label "Belong's to associations"
            field :division
          end
        end
      end

      visit show_path(model_name: 'team', id: team.id)

      is_expected.to have_selector('h4', text: 'Basic info')
      is_expected.to have_selector('h4', text: "Belong's to associations")

      is_expected.to have_selector('.name_field')
      is_expected.to have_selector('.logo_url_field')
      is_expected.to have_selector('.division_field')
    end

    it 'has accessor for its fields by type' do
      RailsAdmin.config Team do
        show do
          group :default do
            field :name
            field :logo_url
          end
          group :other do
            field :division
            field :manager
            field :ballpark
            fields_of_type :string do
              label { "#{label} (STRING)" }
            end
          end
        end
      end

      visit show_path(model_name: 'team', id: team.id)

      is_expected.to have_selector('.label', text: 'Name')
      is_expected.to have_selector('.label', text: 'Logo url')
      is_expected.to have_selector('.label', text: 'Division')
      is_expected.to have_selector('.label', text: 'Manager (STRING)')
      is_expected.to have_selector('.label', text: 'Ballpark (STRING)')
    end
  end

  describe 'fields' do
    before do
      RailsAdmin.config do |c|
        c.compact_show_view = false
      end
    end

    it 'shows all by default' do
      visit show_path(model_name: 'team', id: team.id)

      %w[
        division name logo_url manager
        ballpark mascot founded wins
        losses win_percentage revenue players fans
      ].each do |field|
        is_expected.to have_selector(".#{field}_field")
      end
    end

    it 'only shows the defined fields and appear in order defined' do
      RailsAdmin.config Team do
        show do
          field :manager
          field :division
          field :name
        end
      end

      visit show_path(model_name: 'team', id: team.id)

      is_expected.to have_selector('.manager_field')
      is_expected.to have_selector('.division_field')
      is_expected.to have_selector('.name_field')
    end

    it 'delegates the label option to the ActiveModel API' do
      RailsAdmin.config Team do
        show do
          field :manager
          field :fans
        end
      end

      visit show_path(model_name: 'team', id: team.id)

      is_expected.to have_selector('.label', text: 'Team Manager')
      is_expected.to have_selector('.label', text: 'Some Fans')
    end

    it 'is renameable' do
      RailsAdmin.config Team do
        show do
          field :manager do
            label 'Renamed field'
          end
          field :division
          field :name
        end
      end

      visit show_path(model_name: 'team', id: team.id)

      is_expected.to have_selector('.label', text: 'Renamed field')
      is_expected.to have_selector('.label', text: 'Division')
      is_expected.to have_selector('.label', text: 'Name')
    end

    it 'is renameable by type' do
      RailsAdmin.config Team do
        show do
          fields_of_type :string do
            label { "#{label} (STRING)" }
          end
        end
      end

      visit show_path(model_name: 'team', id: team.id)

      [
        'Division', 'Name (STRING)', 'Logo url (STRING)', 'Manager (STRING)',
        'Ballpark (STRING)', 'Mascot (STRING)', 'Founded', 'Wins', 'Losses',
        'Win percentage', 'Revenue', 'Players', 'Fans'
      ].each do |text|
        is_expected.to have_selector('.label', text: text)
      end
    end

    it 'is globally renameable by type' do
      RailsAdmin.config Team do
        show do
          fields_of_type :string do
            label { "#{label} (STRING)" }
          end
        end
      end

      visit show_path(model_name: 'team', id: team.id)

      [
        'Division', 'Name (STRING)', 'Logo url (STRING)', 'Manager (STRING)',
        'Ballpark (STRING)', 'Mascot (STRING)', 'Founded', 'Wins', 'Losses',
        'Win percentage', 'Revenue', 'Players', 'Fans'
      ].each do |text|
        is_expected.to have_selector('.label', text: text)
      end
    end

    it 'is hideable' do
      RailsAdmin.config Team do
        show do
          field :manager do
            hide
          end
          field :division
          field :name
        end
      end

      visit show_path(model_name: 'team', id: team.id)

      is_expected.to have_selector('.division_field')
      is_expected.to have_selector('.name_field')
    end

    it 'is hideable by type' do
      RailsAdmin.config Team do
        show do
          fields_of_type :string do
            hide
          end
        end
      end

      visit show_path(model_name: 'team', id: team.id)

      %w[Name Logo\ url Manager Ballpark Mascot].each do |text|
        is_expected.not_to have_selector('.label', text: text)
      end

      %w[Division Founded Wins Losses Win\ percentage Revenue Players Fans].each do |text|
        is_expected.to have_selector('.label', text: text)
      end
    end

    it 'is globally hideable by type' do
      RailsAdmin.config Team do
        show do
          fields_of_type :string do
            hide
          end
        end
      end

      visit show_path(model_name: 'team', id: team.id)

      %w[Name Logo\ url Manager Ballpark Mascot].each do |text|
        is_expected.not_to have_selector('.label', text: text)
      end

      %w[Division Founded Wins Losses Win\ percentage Revenue Players Fans].each do |text|
        is_expected.to have_selector('.label', text: text)
      end
    end
  end

  describe 'virtual field' do
    let(:team) { FactoryBot.create :team, name: 'foobar' }
    context 'with formatted_value defined' do
      before do
        RailsAdmin.config Team do
          show do
            field :truncated_name do
              formatted_value do
                bindings[:object].name.truncate(5)
              end
            end
          end
        end
      end

      it 'shows up correctly' do
        visit show_path(model_name: 'team', id: team.id)

        is_expected.to have_selector('.truncated_name_field')
        is_expected.to have_selector('dd', text: 'fo...')
      end
    end

    context 'without formatted_value' do
      before do
        RailsAdmin.config Team do
          show do
            field :truncated_name do
              pretty_value do
                bindings[:object].name.truncate(5)
              end
            end
          end
        end
      end

      it 'raises error along with suggestion' do
        expect { visit show_path(model_name: 'team', id: team.id) }.to raise_error(/you should declare 'formatted_value'/)
      end
    end
  end
end
