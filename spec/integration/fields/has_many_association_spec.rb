require 'spec_helper'

RSpec.describe 'HasManyAssociation field', type: :request do
  subject { page }

  context 'when an association is readonly' do
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

  describe 'on create' do
    before do
      @divisions = Array.new(3) { Division.create!(name: "div #{Time.now.to_f}", league: League.create!(name: "league #{Time.now.to_f}")) }
    end

    it 'shows selects' do
      visit new_path(model_name: 'league')
      is_expected.to have_selector('select#league_division_ids')
    end

    it 'creates an object with correct associations' do
      post new_path(model_name: 'league', league: {name: 'National League', division_ids: [@divisions[0].id]})
      @league = RailsAdmin::AbstractModel.new('League').all.to_a.last
      @divisions[0].reload
      expect(@league.divisions).to include(@divisions[0])
      expect(@league.divisions).not_to include(@divisions[1])
      expect(@league.divisions).not_to include(@divisions[2])
    end
  end

  context 'on update' do
    it 'is fillable and emptyable', active_record: true do
      RailsAdmin.config do |c|
        c.audit_with :history
      end

      @league = FactoryBot.create :league
      @divisions = Array.new(3) { Division.create!(name: "div #{Time.now.to_f}", league: League.create!(name: "league #{Time.now.to_f}")) }

      put edit_path(model_name: 'league', id: @league.id, league: {name: 'National League', division_ids: [@divisions[0].id]})

      old_name = @league.name
      @league.reload
      expect(@league.name).to eq('National League')
      @divisions[0].reload
      expect(@league.divisions).to include(@divisions[0])
      expect(@league.divisions).not_to include(@divisions[1])
      expect(@league.divisions).not_to include(@divisions[2])

      expect(RailsAdmin::History.where(item: @league.id).collect(&:message)).to include("name: \"#{old_name}\" -> \"National League\"")

      put edit_path(model_name: 'league', id: @league.id, league: {division_ids: ['']})

      @league.reload
      expect(@league.divisions).to be_empty
    end

    context 'with embedded model', mongoid: true do
      it 'is editable' do
        @record = FactoryBot.create :field_test
        2.times.each { |i| @record.embeds.create name: "embed #{i}" }
        visit edit_path(model_name: 'field_test', id: @record.id)
        fill_in 'field_test_embeds_attributes_0_name', with: 'embed 1 edited'
        page.find('#field_test_embeds_attributes_1__destroy', visible: false).set('true')
        click_button 'Save' # first(:button, "Save").click
        @record.reload
        expect(@record.embeds.length).to eq(1)
        expect(@record.embeds[0].name).to eq('embed 1 edited')
      end
    end
  end

  context 'on show' do
    context 'with embedded model', mongoid: true do
      it "does not show link to individual object's page" do
        @record = FactoryBot.create :field_test
        2.times.each { |i| @record.embeds.create name: "embed #{i}" }
        visit show_path(model_name: 'field_test', id: @record.id)
        is_expected.not_to have_link('embed 0')
        is_expected.not_to have_link('embed 1')
      end
    end
  end

  context 'on list' do
    context 'with embedded model', mongoid: true do
      it "does not show link to individual object's page" do
        RailsAdmin.config FieldTest do
          list do
            field :embeds
          end
        end
        @record = FactoryBot.create :field_test
        2.times.each { |i| @record.embeds.create name: "embed #{i}" }
        visit index_path(model_name: 'field_test')
        is_expected.not_to have_link('embed 0')
        is_expected.not_to have_link('embed 1')
      end
    end
  end

  describe 'nested form' do
    it 'works', js: true do
      @record = FactoryBot.create :field_test
      NestedFieldTest.create! title: 'title 1', field_test: @record
      NestedFieldTest.create! title: 'title 2', field_test: @record
      visit edit_path(model_name: 'field_test', id: @record.id)

      fill_in 'field_test_nested_field_tests_attributes_0_title', with: 'nested field test title 1 edited', visible: false
      find('#field_test_nested_field_tests_attributes_1__destroy', visible: false).set('true')

      # trigger click via JS, workaround for instability in CI
      execute_script %($('button[name="_save"]').trigger('click');)
      is_expected.to have_content('Field test successfully updated')

      @record.reload
      expect(@record.nested_field_tests.length).to eq(1)
      expect(@record.nested_field_tests[0].title).to eq('nested field test title 1 edited')
    end

    it 'supports adding new nested item', js: true do
      @record = FactoryBot.create :field_test
      visit edit_path(model_name: 'field_test', id: @record.id)

      find('#field_test_nested_field_tests_attributes_field .add_nested_fields').click

      expect(page).to have_selector('.fields.tab-pane.active', visible: true)
    end

    it 'sets bindings[:object] to nested object' do
      RailsAdmin.config(NestedFieldTest) do
        nested do
          field :title do
            label do
              bindings[:object].class.name
            end
          end
        end
      end
      @record = FieldTest.create
      NestedFieldTest.create! title: 'title 1', field_test: @record
      visit edit_path(model_name: 'field_test', id: @record.id)
      expect(find('#field_test_nested_field_tests_attributes_0_title_field')).to have_content('NestedFieldTest')
    end

    it 'is deactivatable' do
      visit new_path(model_name: 'field_test')
      is_expected.to have_selector('#field_test_nested_field_tests_attributes_field .add_nested_fields')
      RailsAdmin.config(FieldTest) do
        configure :nested_field_tests do
          nested_form false
        end
      end
      visit new_path(model_name: 'field_test')
      is_expected.to have_no_selector('#field_test_nested_field_tests_attributes_field .add_nested_fields')
    end

    context 'with nested_attributes_options given' do
      before do
        allow(FieldTest.nested_attributes_options).to receive(:[]).with(any_args).
          and_return(allow_destroy: true, update_only: false)
      end

      it 'does not show add button when :update_only is true' do
        allow(FieldTest.nested_attributes_options).to receive(:[]).with(:nested_field_tests).
          and_return(allow_destroy: true, update_only: true)
        visit new_path(model_name: 'field_test')
        is_expected.to have_selector('.toggler')
        is_expected.not_to have_selector('#field_test_nested_field_tests_attributes_field .add_nested_fields')
      end

      it 'does not show destroy button except for newly created when :allow_destroy is false' do
        @record = FieldTest.create
        NestedFieldTest.create! title: 'nested title 1', field_test: @record
        allow(FieldTest.nested_attributes_options).to receive(:[]).with(:nested_field_tests).
          and_return(allow_destroy: false, update_only: false)
        visit edit_path(model_name: 'field_test', id: @record.id)
        expect(find('#field_test_nested_field_tests_attributes_0_title').value).to eq('nested title 1')
        is_expected.not_to have_selector('form .remove_nested_fields')
        expect(find('div#nested_field_tests_fields_blueprint', visible: false)[:'data-blueprint']).to match(
          /<a[^>]* class="remove_nested_fields"[^>]*>/,
        )
      end
    end

    context "when a field which have the same name of nested_in field's" do
      it "does not hide fields which are not associated with nesting parent field's model" do
        visit new_path(model_name: 'field_test')
        is_expected.not_to have_selector('select#field_test_nested_field_tests_attributes_new_nested_field_tests_field_test_id')
        expect(find('div#nested_field_tests_fields_blueprint', visible: false)[:'data-blueprint']).to match(
          /<select[^>]* id="field_test_nested_field_tests_attributes_new_nested_field_tests_another_field_test_id"[^>]*>/,
        )
      end

      it 'hides fields that are deeply nested with inverse_of' do
        visit new_path(model_name: 'field_test')
        expect(page.body).to_not include('field_test_nested_field_tests_attributes_new_nested_field_tests_deeply_nested_field_tests_attributes_new_deeply_nested_field_tests_nested_field_test_id_field')
        expect(page.body).to include('field_test_nested_field_tests_attributes_new_nested_field_tests_deeply_nested_field_tests_attributes_new_deeply_nested_field_tests_title')
      end
    end

    context 'when XSS attack is attempted', js: true do
      it 'does not break on adding a new item' do
        allow(I18n).to receive(:t).and_call_original
        expect(I18n).to receive(:t).with('admin.form.new_model', name: 'Nested field test').and_return('<script>throw "XSS";</script>')
        @record = FactoryBot.create :field_test
        visit edit_path(model_name: 'field_test', id: @record.id)
        find('#field_test_nested_field_tests_attributes_field .add_nested_fields').click
      end

      it 'does not break on editing an existing item' do
        @record = FactoryBot.create :field_test
        NestedFieldTest.create! title: '<script>throw "XSS";</script>', field_test: @record
        visit edit_path(model_name: 'field_test', id: @record.id)
      end
    end
  end

  context 'with not nullable foreign key', active_record: true do
    before do
      RailsAdmin.config FieldTest do
        edit do
          field :nested_field_tests do
            nested_form false
          end
        end
      end
      @field_test = FactoryBot.create :field_test
    end

    it 'don\'t allow to remove element', js: true do
      visit edit_path(model_name: 'FieldTest', id: @field_test.id)
      is_expected.not_to have_selector('a.ra-multiselect-item-remove')
      is_expected.not_to have_selector('a.ra-multiselect-item-remove-all')
    end
  end

  context 'with nullable foreign key', active_record: true do
    before do
      RailsAdmin.config Team do
        edit do
          field :players
        end
      end
      @team = FactoryBot.create :team
    end

    it 'allow to remove element', js: true do
      visit edit_path(model_name: 'Team', id: @team.id)
      is_expected.to have_selector('a.ra-multiselect-item-remove')
      is_expected.to have_selector('a.ra-multiselect-item-remove-all')
    end
  end

  context 'with custom primary_key option' do
    let(:user) { FactoryBot.create :managing_user }
    let!(:teams) { [FactoryBot.create(:managed_team, manager: user.email), FactoryBot.create(:managed_team)] }
    before do
      RailsAdmin.config.included_models = [ManagingUser, ManagedTeam]
      RailsAdmin.config ManagingUser do
        field :teams
      end
    end

    it 'allows update' do
      visit edit_path(model_name: 'managing_user', id: user.id)
      expect(find("select#managing_user_team_ids option[value=\"#{teams[0].id}\"]")).to have_content teams[0].name
      select(teams[1].name, from: 'Teams')
      click_button 'Save'
      expect(ManagingUser.first.teams).to match_array teams
    end

    context 'when fetching associated objects via xhr' do
      before do
        RailsAdmin.config ManagingUser do
          field(:teams) { associated_collection_cache_all false }
        end
      end

      it 'allows update', js: true do
        visit edit_path(model_name: 'managing_user', id: user.id)
        find('input.ra-multiselect-search').set('T')
        page.execute_script("$('input.ra-multiselect-search').trigger('focus')")
        page.execute_script("$('input.ra-multiselect-search').trigger('keydown')")
        find('.ra-multiselect-collection option', text: teams[1].name).select_option
        find('.ra-multiselect-item-add').click
        click_button 'Save'
        expect(ManagingUser.first.teams).to match_array teams
      end
    end
  end
end
