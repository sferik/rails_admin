require 'spec_helper'

RSpec.describe 'Edit action', type: :request do
  subject { page }

  describe 'page' do
    before do
      @player = FactoryBot.create :player
      visit edit_path(model_name: 'player', id: @player.id)
    end

    it 'shows "Edit model"' do
      is_expected.to have_content('Edit Player')
    end

    it 'shows required fields as "Required"' do
      is_expected.to have_selector('div', text: /Name\s*Required/)
      is_expected.to have_selector('div', text: /Number\s*Required/)
    end

    it 'shows non-required fields as "Optional"' do
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

  describe 'css hooks' do
    it 'is present' do
      visit new_path(model_name: 'team')
      is_expected.to have_selector('#team_division_id_field.belongs_to_association_type.division_field')
    end
  end

  describe 'field grouping' do
    it 'is hideable' do
      RailsAdmin.config Team do
        edit do
          group :default do
            label 'Hidden group'
            hide
          end
        end
      end
      visit new_path(model_name: 'team')
      # Should not have the group header
      is_expected.to have_no_selector('legend', text: 'Hidden Group')
      # Should not have any of the group's fields either
      is_expected.to have_no_selector('select#team_division')
      is_expected.to have_no_selector('input#team_name')
      is_expected.to have_no_selector('input#team_logo_url')
      is_expected.to have_no_selector('input#team_manager')
      is_expected.to have_no_selector('input#team_ballpark')
      is_expected.to have_no_selector('input#team_mascot')
      is_expected.to have_no_selector('input#team_founded')
      is_expected.to have_no_selector('input#team_wins')
      is_expected.to have_no_selector('input#team_losses')
      is_expected.to have_no_selector('input#team_win_percentage')
      is_expected.to have_no_selector('input#team_revenue')
    end

    it 'hides association groupings' do
      RailsAdmin.config Team do
        edit do
          group :players do
            label 'Players'
            field :players
            hide
          end
        end
      end
      visit new_path(model_name: 'team')
      # Should not have the group header
      is_expected.to have_no_selector('legend', text: 'Players')
      # Should not have any of the group's fields either
      is_expected.to have_no_selector('select#team_player_ids')
    end

    it 'is renameable' do
      RailsAdmin.config Team do
        edit do
          group :default do
            label 'Renamed group'
          end
        end
      end
      visit new_path(model_name: 'team')
      # NOTE: capybara 2.0 is exceedingly reluctant to reveal the text of invisible elements. This was
      # the least terrible option I was able to find. It would probably be better to refactor the test
      # so the label we're looking for is displayed.
      expect(find('legend', visible: false).native.text).to include('Renamed group')
    end

    describe 'help' do
      before do
        class HelpTest < Tableless
          column :name, 'varchar(50)'
          column :division, :varchar
        end
        RailsAdmin.config.included_models = [HelpTest, Team]
      end

      after(:each) do
        # restore validation setting
        HelpTest._validators[:name] = []
        HelpTest.reset_callbacks(:validate)
      end

      context 'using mongoid', skip_active_record: true do
        it 'uses the db column size for the maximum length' do
          visit new_path(model_name: 'help_test')
          expect(find('#help_test_name_field .help-block')).to have_content('Length up to 255.')
        end

        it 'returns nil for the maximum length' do
          visit new_path(model_name: 'team')
          expect(find('#team_custom_field_field .help-block')).not_to have_content('Length')
        end
      end

      context 'using active_record', skip_mongoid: true do
        it 'uses the db column size for the maximum length' do
          visit new_path(model_name: 'help_test')
          expect(find('#help_test_name_field .help-block')).to have_content('Length up to 50.')
        end

        it 'uses the :minimum setting from the validation' do
          HelpTest.class_eval do
            validates_length_of :name, minimum: 1
          end
          visit new_path(model_name: 'help_test')
          expect(find('#help_test_name_field .help-block')).to have_content('Length of 1-50.')
        end

        it 'uses the minimum of db column size or :maximum setting from the validation' do
          HelpTest.class_eval do
            validates_length_of :name, maximum: 51
          end
          visit new_path(model_name: 'help_test')
          expect(find('#help_test_name_field .help-block')).to have_content('Length up to 50.')
        end
      end

      it 'shows help section if present' do
        RailsAdmin.config HelpTest do
          edit do
            group :default do
              help 'help paragraph to display'
            end
          end
        end
        visit new_path(model_name: 'help_test')
        is_expected.to have_selector('fieldset>p', text: 'help paragraph to display')
      end

      it 'does not show help if not present' do
        RailsAdmin.config HelpTest do
          edit do
            group :default do
              label 'no help'
            end
          end
        end
        visit new_path(model_name: 'help_test')
        is_expected.not_to have_selector('fieldset>p')
      end

      it 'is able to display multiple help if there are multiple sections' do
        RailsAdmin.config HelpTest do
          edit do
            group :default do
              field :name
              help 'help for default'
            end
            group :other_section do
              label 'Other Section'
              field :division
              help 'help for other section'
            end
          end
        end
        visit new_path(model_name: 'help_test')
        is_expected.to have_selector('fieldset>p', text: 'help for default')
        is_expected.to have_selector('fieldset>p', text: 'help for other section')
        is_expected.to have_selector('fieldset>p', count: 2)
      end

      it 'uses the :is setting from the validation' do
        HelpTest.class_eval do
          validates_length_of :name, is: 3
        end
        visit new_path(model_name: 'help_test')
        expect(find('#help_test_name_field .help-block')).to have_content('Length of 3.')
      end

      it 'uses the :maximum setting from the validation' do
        HelpTest.class_eval do
          validates_length_of :name, maximum: 49
        end
        visit new_path(model_name: 'help_test')
        expect(find('#help_test_name_field .help-block')).to have_content('Length up to 49.')
      end

      it 'uses the :minimum and :maximum from the validation' do
        HelpTest.class_eval do
          validates_length_of :name, minimum: 1, maximum: 49
        end
        visit new_path(model_name: 'help_test')
        expect(find('#help_test_name_field .help-block')).to have_content('Length of 1-49.')
      end

      it 'uses the range from the validation' do
        HelpTest.class_eval do
          validates_length_of :name, in: 1..49
        end
        visit new_path(model_name: 'help_test')
        expect(find('#help_test_name_field .help-block')).to have_content('Length of 1-49.')
      end

      it 'does not show help for hidden fields' do
        RailsAdmin.config HelpTest do
          edit do
            field :name, :hidden
          end
        end
        visit new_path(model_name: 'help_test')
        expect(page).not_to have_css('.help-block')
      end
    end

    it 'has accessor for its fields' do
      RailsAdmin.config Team do
        edit do
          group :default do
            field :name
            field :logo_url
          end
          group :belongs_to_associations do
            label "Belong's to associations"
            field :division
          end
          group :basic_info do
            field :manager
          end
        end
      end
      visit new_path(model_name: 'team')
      is_expected.to have_selector('legend', text: 'Basic info', visible: false)
      is_expected.to have_selector('legend', text: 'Basic info', visible: true)
      is_expected.to have_selector('legend', text: "Belong's to associations")
      is_expected.to have_selector('label', text: 'Name')
      is_expected.to have_selector('label', text: 'Logo url')
      is_expected.to have_selector('label', text: 'Division')
      is_expected.to have_selector('.control-group', count: 4)
    end

    it 'has accessor for its fields by type' do
      RailsAdmin.config Team do
        edit do
          group :default do
            field :name
            field :logo_url
          end
          group :other do
            field :division_id
            field :manager
            field :ballpark
            fields_of_type :string do
              label { "#{label} (STRING)" }
            end
          end
        end
      end
      visit new_path(model_name: 'team')
      is_expected.to have_selector('label', text: 'Name')
      is_expected.to have_selector('label', text: 'Logo url')
      is_expected.to have_selector('label', text: 'Division')
      is_expected.to have_selector('label', text: 'Manager (STRING)')
      is_expected.to have_selector('label', text: 'Ballpark (STRING)')
    end
  end

  describe 'fields' do
    it 'shows all by default' do
      visit new_path(model_name: 'team')
      is_expected.to have_selector('select#team_division_id')
      is_expected.to have_selector('input#team_name')
      is_expected.to have_selector('input#team_logo_url')
      is_expected.to have_selector('input#team_manager')
      is_expected.to have_selector('input#team_ballpark')
      is_expected.to have_selector('input#team_mascot')
      is_expected.to have_selector('input#team_founded')
      is_expected.to have_selector('input#team_wins')
      is_expected.to have_selector('input#team_losses')
      is_expected.to have_selector('input#team_win_percentage')
      is_expected.to have_selector('input#team_revenue')
      is_expected.to have_selector('select#team_player_ids')
      is_expected.to have_selector('select#team_fan_ids')
    end

    it 'appears in order defined' do
      RailsAdmin.config Team do
        edit do
          field :manager
          field :division
          field :name
        end
      end
      visit new_path(model_name: 'team')
      is_expected.to have_selector(:xpath, "//*[contains(@class, 'field')][1]//*[@id='team_manager']")
      is_expected.to have_selector(:xpath, "//*[contains(@class, 'field')][2]//*[@id='team_division_id']")
      is_expected.to have_selector(:xpath, "//*[contains(@class, 'field')][3]//*[@id='team_name']")
    end

    it 'only shows the defined fields if some fields are defined' do
      RailsAdmin.config Team do
        edit do
          field :division
          field :name
        end
      end
      visit new_path(model_name: 'team')
      is_expected.to have_selector('label', text: 'Division')
      is_expected.to have_selector('label', text: 'Name')
      is_expected.to have_selector('.control-group', count: 2)
    end

    describe 'I18n awarly' do
      after :each do
        I18n.locale = :en
      end

      it 'delegates the label option to the ActiveModel API and memoizes it' do
        RailsAdmin.config Team do
          edit do
            field :manager
            field :fans
          end
        end
        visit new_path(model_name: 'team')
        is_expected.to have_selector('label', text: 'Team Manager')
        is_expected.to have_selector('label', text: 'Some Fans')
        I18n.locale = :fr
        visit new_path(model_name: 'team')
        is_expected.to have_selector('label', text: "Manager de l'équipe")
        is_expected.to have_selector('label', text: 'Quelques fans')
      end
    end

    it 'is renameable' do
      RailsAdmin.config Team do
        edit do
          field :manager do
            label 'Renamed field'
          end
          field :division
          field :name
        end
      end
      visit new_path(model_name: 'team')
      is_expected.to have_selector('label', text: 'Renamed field')
      is_expected.to have_selector('label', text: 'Division')
      is_expected.to have_selector('label', text: 'Name')
    end

    it 'is renameable by type' do
      RailsAdmin.config Team do
        edit do
          fields_of_type :string do
            label { "#{label} (STRING)" }
          end
        end
      end
      visit new_path(model_name: 'team')
      is_expected.to have_selector('label', text: 'Division')
      is_expected.to have_selector('label', text: 'Name (STRING)')
      is_expected.to have_selector('label', text: 'Logo url (STRING)')
      is_expected.to have_selector('label', text: 'Manager (STRING)')
      is_expected.to have_selector('label', text: 'Ballpark (STRING)')
      is_expected.to have_selector('label', text: 'Mascot (STRING)')
      is_expected.to have_selector('label', text: 'Founded')
      is_expected.to have_selector('label', text: 'Wins')
      is_expected.to have_selector('label', text: 'Losses')
      is_expected.to have_selector('label', text: 'Win percentage')
      is_expected.to have_selector('label', text: 'Revenue')
      is_expected.to have_selector('label', text: 'Players')
      is_expected.to have_selector('label', text: 'Fans')
    end

    it 'is globally renameable by type' do
      RailsAdmin.config Team do
        edit do
          fields_of_type :string do
            label { "#{label} (STRING)" }
          end
        end
      end
      visit new_path(model_name: 'team')
      is_expected.to have_selector('label', text: 'Division')
      is_expected.to have_selector('label', text: 'Name (STRING)')
      is_expected.to have_selector('label', text: 'Logo url (STRING)')
      is_expected.to have_selector('label', text: 'Manager (STRING)')
      is_expected.to have_selector('label', text: 'Ballpark (STRING)')
      is_expected.to have_selector('label', text: 'Mascot (STRING)')
      is_expected.to have_selector('label', text: 'Founded')
      is_expected.to have_selector('label', text: 'Wins')
      is_expected.to have_selector('label', text: 'Losses')
      is_expected.to have_selector('label', text: 'Win percentage')
      is_expected.to have_selector('label', text: 'Revenue')
      is_expected.to have_selector('label', text: 'Players')
      is_expected.to have_selector('label', text: 'Fans')
    end

    it 'is flaggable as read only and be configurable with formatted_value' do
      RailsAdmin.config Team do
        edit do
          field :name do
            read_only true
            formatted_value do
              "I'm outputed in the form"
            end
          end
        end
      end
      visit new_path(model_name: 'team')
      is_expected.to have_content("I'm outputed in the form")
    end

    it 'is hideable' do
      RailsAdmin.config Team do
        edit do
          field :manager do
            hide
          end
          field :division
          field :name
        end
      end
      visit new_path(model_name: 'team')
      is_expected.to have_no_selector('#team_manager')
      is_expected.to have_selector('#team_division_id')
      is_expected.to have_selector('#team_name')
    end

    it 'is hideable by type' do
      RailsAdmin.config Team do
        edit do
          fields_of_type :string do
            hide
          end
        end
      end
      visit new_path(model_name: 'team')
      is_expected.to have_selector('label', text: 'Division')
      is_expected.to have_no_selector('label', text: 'Name')
      is_expected.to have_no_selector('label', text: 'Logo url')
      is_expected.to have_no_selector('label', text: 'Manager')
      is_expected.to have_no_selector('label', text: 'Ballpark')
      is_expected.to have_no_selector('label', text: 'Mascot')
      is_expected.to have_selector('label', text: 'Founded')
      is_expected.to have_selector('label', text: 'Wins')
      is_expected.to have_selector('label', text: 'Losses')
      is_expected.to have_selector('label', text: 'Win percentage')
      is_expected.to have_selector('label', text: 'Revenue')
      is_expected.to have_selector('label', text: 'Players')
      is_expected.to have_selector('label', text: 'Fans')
    end

    it 'is globally hideable by type' do
      RailsAdmin.config Team do
        edit do
          fields_of_type :string do
            hide
          end
        end
      end
      visit new_path(model_name: 'team')
      is_expected.to have_selector('label', text: 'Division')
      is_expected.to have_no_selector('label', text: 'Name')
      is_expected.to have_no_selector('label', text: 'Logo url')
      is_expected.to have_no_selector('label', text: 'Manager')
      is_expected.to have_no_selector('label', text: 'Ballpark')
      is_expected.to have_no_selector('label', text: 'Mascot')
      is_expected.to have_selector('label', text: 'Founded')
      is_expected.to have_selector('label', text: 'Wins')
      is_expected.to have_selector('label', text: 'Losses')
      is_expected.to have_selector('label', text: 'Win percentage')
      is_expected.to have_selector('label', text: 'Revenue')
      is_expected.to have_selector('label', text: 'Players')
      is_expected.to have_selector('label', text: 'Fans')
    end

    it 'has option to customize the help text' do
      RailsAdmin.config Team do
        edit do
          field :manager do
            help "#{help} Additional help text for manager field."
          end
          field :division
          field :name
        end
      end
      visit new_path(model_name: 'team')
      expect(find('#team_manager_field .help-block')).to have_content('Required. Length up to 100. Additional help text for manager field.')
      expect(find('#team_division_id_field .help-block')).to have_content('Required')
      expect(find('#team_name_field .help-block')).not_to have_content('Additional help text')
    end

    it 'has option to override required status' do
      RailsAdmin.config Team do
        edit do
          field :manager do
            optional true
          end
          field :division do
            optional true
          end
          field :name do
            required true
          end
        end
      end
      visit new_path(model_name: 'team')
      expect(find('#team_manager_field .help-block')).to have_content('Optional')
      expect(find('#team_division_id_field .help-block')).to have_content('Optional')
      expect(find('#team_name_field .help-block')).to have_content(I18n.translate('admin.help.team.name'))
    end

    describe 'inline_add' do
      it 'can hide the add button on an associated field' do
        RailsAdmin.config Player do
          edit do
            field :team do
              inline_add false
            end
            field :draft do
              inline_add false
            end
            field :comments do
              inline_add false
            end
          end
        end
        visit new_path(model_name: 'player')
        is_expected.to have_no_selector('a', text: 'Add a new Team')
        is_expected.to have_no_selector('a', text: 'Add a new Draft')
        is_expected.to have_no_selector('a', text: 'Add a new Comment')
      end

      it 'can show the add button on an associated field' do
        RailsAdmin.config Player do
          edit do
            field :team do
              inline_add true
            end
            field :draft do
              inline_add true
            end
            field :comments do
              inline_add true
            end
          end
        end
        visit new_path(model_name: 'player')
        is_expected.to have_selector('a', text: 'Add a new Team')
        is_expected.to have_selector('a', text: 'Add a new Draft')
        is_expected.to have_selector('a', text: 'Add a new Comment')
      end

      context 'when the associated model is invisible' do
        before do
          RailsAdmin.config do |config|
            [Team, Draft, Comment].each do |model|
              config.model model do
                visible false
              end
            end
          end
        end

        it 'does not prevent showing the add button' do
          visit new_path(model_name: 'player')
          is_expected.to have_selector('a', text: 'Add a new Team')
          is_expected.to have_selector('a', text: 'Add a new Draft')
          is_expected.to have_selector('a', text: 'Add a new Comment')
        end
      end
    end

    describe 'inline_edit' do
      it 'can hide the edit button on an associated field' do
        RailsAdmin.config Player do
          edit do
            field :team do
              inline_edit false
            end
            field :draft do
              inline_edit false
            end
          end
        end
        visit new_path(model_name: 'player')
        is_expected.to have_no_selector('a', text: 'Edit this Team')
        is_expected.to have_no_selector('a', text: 'Edit this Draft')
      end

      it 'can show the edit button on an associated field' do
        RailsAdmin.config Player do
          edit do
            field :team do
              inline_edit true
            end
            field :draft do
              inline_edit true
            end
          end
        end
        visit new_path(model_name: 'player')
        is_expected.to have_selector('a', text: 'Edit this Team')
        is_expected.to have_selector('a', text: 'Edit this Draft')
      end

      context 'when the associated model is invisible' do
        before do
          RailsAdmin.config do |config|
            [Team, Draft].each do |model|
              config.model model do
                visible false
              end
            end
          end
        end

        it 'does not prevent showing the edit button' do
          visit new_path(model_name: 'player')
          is_expected.to have_selector('a', text: 'Edit this Team')
          is_expected.to have_selector('a', text: 'Edit this Draft')
        end
      end
    end
  end

  context 'with missing object' do
    before do
      visit edit_path(model_name: 'player', id: 1)
    end

    it 'raises NotFound' do
      expect(page.driver.status_code).to eq(404)
    end
  end

  context 'with missing label', given: ['a player exists', 'three teams with no name exist'] do
    before do
      @player = FactoryBot.create :player
      @teams = Array.new(3) { FactoryBot.create :team, name: '' }
      visit edit_path(model_name: 'player', id: @player.id)
    end
  end

  context 'with overridden to_param' do
    before do
      @ball = FactoryBot.create :ball
      visit edit_path(model_name: 'ball', id: @ball.id)
    end

    it 'displays a link to the delete page' do
      is_expected.to have_selector "a[href$='/admin/ball/#{@ball.id}/delete']"
    end
  end

  context 'on cancel' do
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

  context 'on clicking save without changing anything' do
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

  context 'with errors' do
    before do
      @player = FactoryBot.create :player
      visit edit_path(model_name: 'player', id: @player.id)
    end

    it 'returns to edit page' do
      fill_in 'player[name]', with: ''
      click_button 'Save' # first(:button, "Save").click
      expect(page.driver.status_code).to eq(406)
      is_expected.to have_selector "form[action='#{edit_path(model_name: 'player', id: @player.id)}']"
    end
  end

  describe 'add another' do
    before do
      @player = FactoryBot.create :player

      visit edit_path(model_name: 'player', id: @player.id)

      fill_in 'player[name]', with: 'Jackie Robinson'
      fill_in 'player[number]', with: '42'
      fill_in 'player[position]', with: 'Second baseman'
      click_button 'Save' # first(:button, "Save").click

      @player = RailsAdmin::AbstractModel.new('Player').first
    end

    it 'updates an object with correct attributes' do
      expect(@player.name).to eq('Jackie Robinson')
      expect(@player.number).to eq(42)
      expect(@player.position).to eq('Second baseman')
    end
  end

  describe 'update and edit' do
    before do
      @player = FactoryBot.create :player

      visit edit_path(model_name: 'player', id: @player.id)

      fill_in 'player[name]', with: 'Jackie Robinson'
      fill_in 'player[number]', with: '42'
      fill_in 'player[position]', with: 'Second baseman'
      click_button 'Save and edit'

      @player.reload
    end

    it 'updates an object with correct attributes' do
      expect(@player.name).to eq('Jackie Robinson')
      expect(@player.number).to eq(42)
      expect(@player.position).to eq('Second baseman')
    end
  end

  context 'with missing object' do
    before do
      put edit_path(model_name: 'player', id: 1), params: {player: {name: 'Jackie Robinson', number: 42, position: 'Second baseman'}}
    end

    it 'raises NotFound' do
      expect(response.code).to eq('404')
    end
  end

  context 'with invalid object' do
    before do
      @player = FactoryBot.create :player

      visit edit_path(model_name: 'player', id: @player.id)

      fill_in 'player[name]', with: 'Jackie Robinson'
      fill_in 'player[number]', with: 'a'
      fill_in 'player[position]', with: 'Second baseman'
      click_button 'Save' # first(:button, "Save").click

      @player.reload
    end

    it 'shows an error message' do
      expect(Capybara.string(body)).to have_content('Player failed to be updated')
    end
  end

  context 'with overridden to_param' do
    before do
      @ball = FactoryBot.create :ball

      visit edit_path(model_name: 'ball', id: @ball.id)

      fill_in 'ball[color]', with: 'gray'
      click_button 'Save and edit'

      @ball.reload
    end

    it 'updates an object with correct attributes' do
      expect(@ball.color).to eq('gray')
    end
  end

  context 'on update of STI subclass on superclass view' do
    before do
      @hardball = FactoryBot.create :hardball

      visit edit_path(model_name: 'ball', id: @hardball.id)

      fill_in 'ball[color]', with: 'cyan'
      click_button 'Save and edit'

      @hardball.reload
    end

    it 'updates an object with correct attributes' do
      expect(@hardball.color).to eq('cyan')
    end
  end

  context "with a field with 'format' as a name (conflicts with Kernel#format)" do
    it 'is updatable without any error' do
      RailsAdmin.config FieldTest do
        edit do
          field :format
        end
      end
      visit new_path(model_name: 'field_test')
      fill_in 'field_test[format]', with: 'test for format'
      click_button 'Save' # first(:button, "Save").click
      @record = RailsAdmin::AbstractModel.new('FieldTest').first
      expect(@record.format).to eq('test for format')
    end
  end
end
