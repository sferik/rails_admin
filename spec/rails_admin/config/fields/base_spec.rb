require 'spec_helper'

RSpec.describe RailsAdmin::Config::Fields::Base do
  describe '#required' do
    it 'reads the on: :create/:update validate option' do
      RailsAdmin.config Ball do
        field 'color'
      end

      expect(RailsAdmin.config('Ball').fields.first.with(object: Ball.new)).to be_required
      expect(RailsAdmin.config('Ball').fields.first.with(object: FactoryBot.create(:ball))).not_to be_required
    end

    context 'without validation' do
      it 'is optional' do
        # draft.notes is nullable and has no validation
        field = RailsAdmin.config('Draft').edit.fields.detect { |f| f.name == :notes }
        expect(field.properties.nullable?).to be_truthy
        expect(field.required?).to be_falsey
      end
    end

    context 'with presence validation' do
      it 'is required' do
        # draft.date is nullable in the schema but has an AR
        # validates_presence_of validation that makes it required
        field = RailsAdmin.config('Draft').edit.fields.detect { |f| f.name == :date }
        expect(field.properties.nullable?).to be_truthy
        expect(field.required?).to be_truthy
      end
    end

    context 'with numericality validation' do
      it 'is required' do
        # draft.round is nullable in the schema but has an AR
        # validates_numericality_of validation that makes it required
        field = RailsAdmin.config('Draft').edit.fields.detect { |f| f.name == :round }
        expect(field.properties.nullable?).to be_truthy
        expect(field.required?).to be_truthy
      end
    end

    context 'with validation marked as allow_nil or allow_blank' do
      it 'is optional' do
        # team.revenue is nullable in the schema but has an AR
        # validates_numericality_of validation that allows nil
        field = RailsAdmin.config('Team').edit.fields.detect { |f| f.name == :revenue }
        expect(field.properties.nullable?).to be_truthy
        expect(field.required?).to be_falsey

        # team.founded is nullable in the schema but has an AR
        # validates_numericality_of validation that allows blank
        field = RailsAdmin.config('Team').edit.fields.detect { |f| f.name == :founded }
        expect(field.properties.nullable?).to be_truthy
        expect(field.required?).to be_falsey
      end
    end

    context 'with conditional validation' do
      before do
        class ConditionalValidationTest < Tableless
          column :foo, :varchar
          column :bar, :varchar
          validates :foo, presence: true, if: :presisted?
          validates :bar, presence: true, unless: :presisted?
        end
      end

      it 'is optional' do
        expect(RailsAdmin.config('ConditionalValidationTest').fields.detect { |f| f.name == :foo }).not_to be_required
        expect(RailsAdmin.config('ConditionalValidationTest').fields.detect { |f| f.name == :bar }).not_to be_required
      end
    end

    context 'on a Paperclip installation' do
      it 'should detect required fields' do
        expect(RailsAdmin.config('Image').fields.detect { |f| f.name == :file }.with(object: Image.new)).to be_required
      end
    end

    describe 'associations' do
      before do
        class RelTest < Tableless
          column :league_id, :integer
          column :division_id, :integer, nil, false
          column :player_id, :integer
          belongs_to :league, optional: true
          belongs_to :division, optional: true
          belongs_to :player, optional: true
          validates_numericality_of(:player_id, only_integer: true)
        end
        @fields = RailsAdmin.config(RelTest).create.fields
      end

      describe 'for column with nullable foreign key and no model validations' do
        it 'is optional' do
          expect(@fields.detect { |f| f.name == :league }.required?).to be_falsey
        end
      end

      describe 'for column with non-nullable foreign key and no model validations' do
        it 'is optional' do
          expect(@fields.detect { |f| f.name == :division }.required?).to be_falsey
        end
      end

      describe 'for column with nullable foreign key and a numericality model validation' do
        it 'is required' do
          expect(@fields.detect { |f| f.name == :player }.required?).to be_truthy
        end
      end
    end
  end

  describe '#name' do
    it 'is normalized to Symbol' do
      RailsAdmin.config Team do
        field 'name'
      end
      expect(RailsAdmin.config('Team').fields.first.name).to eq(:name)
    end
  end

  describe '#children_fields' do
    POLYMORPHIC_CHILDREN = %i[commentable_id commentable_type].freeze

    it 'is empty by default' do
      expect(RailsAdmin.config(Team).fields.detect { |f| f.name == :name }.children_fields).to eq([])
    end

    it 'contains child key for belongs to associations' do
      expect(RailsAdmin.config(Team).fields.detect { |f| f.name == :division }.children_fields).to eq([:division_id])
    end

    it 'contains child keys for polymorphic belongs to associations' do
      expect(RailsAdmin.config(Comment).fields.detect { |f| f.name == :commentable }.children_fields).to match_array POLYMORPHIC_CHILDREN
    end

    it 'has correct fields when polymorphic_type column comes ahead of polymorphic foreign_key column' do
      class CommentReversed < Tableless
        column :commentable_type, :varchar
        column :commentable_id, :integer
        belongs_to :commentable, polymorphic: true
      end
      expect(RailsAdmin.config(CommentReversed).fields.collect { |f| f.name.to_s }.select { |f| /^comment/ =~ f }).to match_array ['commentable'].concat(POLYMORPHIC_CHILDREN.collect(&:to_s))
    end

    context 'of a Paperclip installation' do
      it 'is a _file_name field' do
        expect(RailsAdmin.config(FieldTest).fields.detect { |f| f.name == :paperclip_asset }.children_fields.include?(:paperclip_asset_file_name)).to be_truthy
      end

      it 'is hidden, not filterable' do
        field = RailsAdmin.config(FieldTest).fields.detect { |f| f.name == :paperclip_asset_file_name }
        expect(field.hidden?).to be_truthy
        expect(field.filterable?).to be_falsey
      end
    end

    context 'of a Dragonfly installation' do
      it 'is a _name field and _uid field' do
        expect(RailsAdmin.config(FieldTest).fields.detect { |f| f.name == :dragonfly_asset }.children_fields).to eq(%i[dragonfly_asset_name dragonfly_asset_uid])
      end
    end

    context 'of a Carrierwave installation' do
      it 'is the parent field itself' do
        expect(RailsAdmin.config(FieldTest).fields.detect { |f| f.name == :carrierwave_asset }.children_fields).to eq([:carrierwave_asset])
        expect(RailsAdmin.config(FieldTest).fields.detect { |f| f.name == :carrierwave_asset }.hidden?).to be_falsey
      end
    end

    context 'of a Carrierwave installation with multiple file support' do
      it 'is the parent field itself' do
        expect(RailsAdmin.config(FieldTest).fields.detect { |f| f.name == :carrierwave_assets }.children_fields).to eq([:carrierwave_assets])
        expect(RailsAdmin.config(FieldTest).fields.detect { |f| f.name == :carrierwave_assets }.hidden?).to be_falsey
      end
    end

    if defined?(ActiveStorage)
      context 'of a ActiveStorage installation' do
        it 'is _attachment and _blob fields' do
          expect(RailsAdmin.config(FieldTest).fields.detect { |f| f.name == :active_storage_asset }.children_fields).to match_array %i[active_storage_asset_attachment active_storage_asset_blob]
        end

        it 'is hidden, not filterable' do
          fields = RailsAdmin.config(FieldTest).fields.select { |f| %i[active_storage_asset_attachment active_storage_asset_blob].include?(f.name) }
          expect(fields).to all(be_hidden)
          expect(fields).not_to include(be_filterable)
        end
      end

      context 'of a ActiveStorage installation with multiple file support' do
        it 'is _attachment and _blob fields' do
          expect(RailsAdmin.config(FieldTest).fields.detect { |f| f.name == :active_storage_assets }.children_fields).to match_array %i[active_storage_assets_attachments active_storage_assets_blobs]
        end

        it 'is hidden, not filterable' do
          fields = RailsAdmin.config(FieldTest).fields.select { |f| %i[active_storage_assets_attachments active_storage_assets_blobs].include?(f.name) }
          expect(fields).to all(be_hidden)
          expect(fields).not_to include(be_filterable)
        end
      end
    end

    if defined?(Shrine)
      context 'of a Shrine installation' do
        it 'is the parent field itself' do
          expect(RailsAdmin.config(FieldTest).fields.detect { |f| f.name == :shrine_asset }.children_fields).to eq([:shrine_asset_data])
          expect(RailsAdmin.config(FieldTest).fields.detect { |f| f.name == :shrine_asset }.hidden?).to be_falsey
        end

        it 'is not filterable' do
          fields = RailsAdmin.config(FieldTest).fields.select { |f| [:shrine_asset_data].include?(f.name) }
          expect(fields).to all(be_hidden)
          expect(fields).not_to include(be_filterable)
        end
      end
    end
  end

  describe '#form_default_value' do
    it 'is default_value for new records when value is nil' do
      RailsAdmin.config Team do
        list do
          field :name do
            default_value 'default value'
          end
        end
      end
      @team = Team.new
      expect(RailsAdmin.config('Team').list.fields.detect { |f| f.name == :name }.with(object: @team).form_default_value).to eq('default value')
      @team.name = 'set value'
      expect(RailsAdmin.config('Team').list.fields.detect { |f| f.name == :name }.with(object: @team).form_default_value).to be_nil
      @team = FactoryBot.create :team
      @team.name = nil
      expect(RailsAdmin.config('Team').list.fields.detect { |f| f.name == :name }.with(object: @team).form_default_value).to be_nil
    end
  end

  describe '#default_value' do
    it 'is nil by default' do
      expect(RailsAdmin.config('Team').list.fields.detect { |f| f.name == :name }.default_value).to be_nil
    end
  end

  describe '#hint' do
    it 'is user customizable' do
      RailsAdmin.config Team do
        list do
          field :division do
            hint 'Great Division'
          end
          field :name
        end
      end
      expect(RailsAdmin.config('Team').list.fields.detect { |f| f.name == :division }.hint).to eq('Great Division') # custom
      expect(RailsAdmin.config('Team').list.fields.detect { |f| f.name == :name }.hint).to eq('') # default
    end
  end

  describe '#help' do
    it 'has a default and be user customizable via i18n' do
      RailsAdmin.config Team do
        list do
          field :division
          field :name
        end
      end
      field_specific_i18n = RailsAdmin.config('Team').list.fields.detect { |f| f.name == :name }
      expect(field_specific_i18n.help).to eq(I18n.translate('admin.help.team.name')) # custom via locales yml
      field_no_specific_i18n = RailsAdmin.config('Team').list.fields.detect { |f| f.name == :division }
      expect(field_no_specific_i18n.help).to eq(field_no_specific_i18n.generic_help) # rails_admin generic fallback
    end
  end

  describe '#css_class' do
    it 'has a default and be user customizable' do
      RailsAdmin.config Team do
        list do
          field :division do
            css_class 'custom'
          end
          field :name
        end
      end
      expect(RailsAdmin.config('Team').list.fields.detect { |f| f.name == :division }.css_class).to eq('custom') # custom
      expect(RailsAdmin.config('Team').list.fields.detect { |f| f.name == :division }.type_css_class).to eq('belongs_to_association_type') # type css class, non-customizable
      expect(RailsAdmin.config('Team').list.fields.detect { |f| f.name == :name }.css_class).to eq('name_field') # default
    end
  end

  describe '#associated_collection_cache_all' do
    it 'defaults to true if associated collection count < 100' do
      expect(RailsAdmin.config(Team).edit.fields.detect { |f| f.name == :players }.associated_collection_cache_all).to be_truthy
    end

    it 'defaults to false if associated collection count >= 100' do
      @players = Array.new(100) do
        FactoryBot.create :player
      end
      expect(RailsAdmin.config(Team).edit.fields.detect { |f| f.name == :players }.associated_collection_cache_all).to be_falsey
    end

    context 'with custom configuration' do
      before do
        RailsAdmin.config.default_associated_collection_limit = 5
      end
      it 'defaults to true if associated collection count less than than limit' do
        @players = Array.new(4) do
          FactoryBot.create :player
        end
        expect(RailsAdmin.config(Team).edit.fields.detect { |f| f.name == :players }.associated_collection_cache_all).to be_truthy
      end

      it 'defaults to false if associated collection count >= that limit' do
        @players = Array.new(5) do
          FactoryBot.create :player
        end
        expect(RailsAdmin.config(Team).edit.fields.detect { |f| f.name == :players }.associated_collection_cache_all).to be_falsey
      end
    end
  end

  describe '#searchable_columns' do
    describe 'for belongs_to fields' do
      it 'finds label method on the opposite side for belongs_to associations by default' do
        expect(RailsAdmin.config(Team).fields.detect { |f| f.name == :division }.searchable_columns.collect { |c| c[:column] }).to eq(['divisions.name', 'teams.division_id'])
      end

      it 'searches on opposite table for belongs_to' do
        RailsAdmin.config(Team) do
          field :division do
            searchable :custom_id
          end
        end
        expect(RailsAdmin.config(Team).fields.detect { |f| f.name == :division }.searchable_columns.collect { |c| c[:column] }).to eq(['divisions.custom_id'])
      end

      it 'searches on asked table with model name' do
        RailsAdmin.config(Team) do
          field :division do
            searchable League => :name
          end
        end
        expect(RailsAdmin.config(Team).fields.detect { |f| f.name == :division }.searchable_columns).to eq([{column: 'leagues.name', type: :string}])
      end

      it 'searches on asked table with table name' do
        RailsAdmin.config(Team) do
          field :division do
            searchable leagues: :name
          end
        end
        expect(RailsAdmin.config(Team).fields.detect { |f| f.name == :division }.searchable_columns).to eq([{column: 'leagues.name', type: :string}])
      end
    end

    describe 'for basic type fields' do
      it 'uses base table and find correct column type' do
        expect(RailsAdmin.config(FieldTest).fields.detect { |f| f.name == :text_field }.searchable_columns).to eq([{column: 'field_tests.text_field', type: :text}])
        expect(RailsAdmin.config(FieldTest).fields.detect { |f| f.name == :integer_field }.searchable_columns).to eq([{column: 'field_tests.integer_field', type: :integer}])
      end

      it 'is customizable to another field on the same table' do
        RailsAdmin.config(FieldTest) do
          field :time_field do
            searchable :date_field
          end
        end
        expect(RailsAdmin.config(FieldTest).fields.detect { |f| f.name == :time_field }.searchable_columns).to eq([{column: 'field_tests.date_field', type: :date}])
      end

      it 'is customizable to another field on another table with :table_name' do
        RailsAdmin.config(FieldTest) do
          field :string_field do
            searchable nested_field_tests: :title
          end
        end
        expect(RailsAdmin.config(FieldTest).fields.detect { |f| f.name == :string_field }.searchable_columns).to eq([{column: 'nested_field_tests.title', type: :string}])
      end

      it 'is customizable to another field on another model with ModelClass' do
        RailsAdmin.config(FieldTest) do
          field :string_field do
            searchable NestedFieldTest => :title
          end
        end
        expect(RailsAdmin.config(FieldTest).fields.detect { |f| f.name == :string_field }.searchable_columns).to eq([{column: 'nested_field_tests.title', type: :string}])
      end
    end

    describe 'for mapped fields' do
      it 'of paperclip should find the underlying column on the base table' do
        expect(RailsAdmin.config(FieldTest).fields.detect { |f| f.name == :paperclip_asset }.searchable_columns.collect { |c| c[:column] }).to eq(['field_tests.paperclip_asset_file_name'])
      end

      it 'of dragonfly should find the underlying column on the base table' do
        expect(RailsAdmin.config(FieldTest).fields.detect { |f| f.name == :dragonfly_asset }.searchable_columns.collect { |c| c[:column] }).to eq(['field_tests.dragonfly_asset_name'])
      end

      it 'of carrierwave should find the underlying column on the base table' do
        expect(RailsAdmin.config(FieldTest).fields.detect { |f| f.name == :carrierwave_asset }.searchable_columns.collect { |c| c[:column] }).to eq(['field_tests.carrierwave_asset'])
      end
    end
  end

  describe '#searchable and #sortable' do
    it 'is false if column is virtual, true otherwise' do
      RailsAdmin.config League do
        field :virtual_column
        field :name
      end
      @league = FactoryBot.create :league
      expect(RailsAdmin.config('League').export.fields.detect { |f| f.name == :virtual_column }.sortable).to be_falsey
      expect(RailsAdmin.config('League').export.fields.detect { |f| f.name == :virtual_column }.searchable).to be_falsey
      expect(RailsAdmin.config('League').export.fields.detect { |f| f.name == :name }.sortable).to be_truthy
      expect(RailsAdmin.config('League').export.fields.detect { |f| f.name == :name }.searchable).to be_truthy
    end

    context 'of a virtual field with children fields' do
      it 'of paperclip should target the first children field' do
        expect(RailsAdmin.config(FieldTest).fields.detect { |f| f.name == :paperclip_asset }.searchable).to eq(:paperclip_asset_file_name)
        expect(RailsAdmin.config(FieldTest).fields.detect { |f| f.name == :paperclip_asset }.sortable).to eq(:paperclip_asset_file_name)
      end

      it 'of dragonfly should target the first children field' do
        expect(RailsAdmin.config(FieldTest).fields.detect { |f| f.name == :dragonfly_asset }.searchable).to eq(:dragonfly_asset_name)
        expect(RailsAdmin.config(FieldTest).fields.detect { |f| f.name == :dragonfly_asset }.sortable).to eq(:dragonfly_asset_name)
      end

      it 'of carrierwave should target the first children field' do
        expect(RailsAdmin.config(FieldTest).fields.detect { |f| f.name == :carrierwave_asset }.searchable).to eq(:carrierwave_asset)
        expect(RailsAdmin.config(FieldTest).fields.detect { |f| f.name == :carrierwave_asset }.sortable).to eq(:carrierwave_asset)
      end
    end
  end

  describe '#virtual?' do
    it 'is true if column has no properties, false otherwise' do
      RailsAdmin.config League do
        field :virtual_column
        field :name
      end
      @league = FactoryBot.create :league
      expect(RailsAdmin.config('League').export.fields.detect { |f| f.name == :virtual_column }.virtual?).to be_truthy
      expect(RailsAdmin.config('League').export.fields.detect { |f| f.name == :name }.virtual?).to be_falsey
    end
  end

  describe '#default_search_operator' do
    let(:abstract_model) { RailsAdmin::AbstractModel.new('Player') }
    let(:model_config) { RailsAdmin.config(abstract_model) }
    let(:queryable_fields) { model_config.list.fields.select(&:queryable?) }

    context 'when no search operator is specified for the field' do
      it "uses 'default' search operator" do
        expect(queryable_fields.size).to be >= 1
        expect(queryable_fields.first.search_operator).to eq(RailsAdmin::Config.default_search_operator)
      end

      it 'uses config.default_search_operator if set' do
        RailsAdmin.config do |config|
          config.default_search_operator = 'starts_with'
        end
        expect(queryable_fields.size).to be >= 1
        expect(queryable_fields.first.search_operator).to eq(RailsAdmin::Config.default_search_operator)
      end
    end

    context 'when search operator is specified for the field' do
      it 'uses specified search operator' do
        RailsAdmin.config Player do
          list do
            fields do
              search_operator 'starts_with'
            end
          end
        end
        expect(queryable_fields.size).to be >= 1
        expect(queryable_fields.first.search_operator).to eq('starts_with')
      end

      it 'uses specified search operator even if config.default_search_operator set' do
        RailsAdmin.config do |config|
          config.default_search_operator = 'starts_with'

          config.model Player do
            list do
              fields do
                search_operator 'ends_with'
              end
            end
          end
        end
        expect(queryable_fields.size).to be >= 1
        expect(queryable_fields.first.search_operator).to eq('ends_with')
      end
    end
  end

  describe '#render' do
    it 'is configurable' do
      RailsAdmin.config Team do
        field :name do
          render do
            'rendered'
          end
        end
      end
      expect(RailsAdmin.config(Team).field(:name).render).to eq('rendered')
    end
  end

  describe '#active' do
    it 'is false by default' do
      expect(RailsAdmin.config(Team).field(:division).active?).to be_falsey
    end
  end

  describe '#associated_collection' do
    it 'returns [] when type is blank?' do
      expect(RailsAdmin.config(Comment).fields.detect { |f| f.name == :commentable }.associated_collection('')).to be_empty
    end
  end

  describe '#visible?' do
    it 'is false when fields have specific name ' do
      class FieldVisibilityTest < Tableless
        column :id, :integer
        column :_id, :integer
        column :_type, :varchar
        column :name, :varchar
        column :created_at, :timestamp
        column :updated_at, :timestamp
        column :deleted_at, :timestamp
        column :created_on, :timestamp
        column :updated_on, :timestamp
        column :deleted_on, :timestamp
      end
      expect(RailsAdmin.config(FieldVisibilityTest).base.fields.select(&:visible?).collect(&:name)).to match_array %i[_id created_at created_on deleted_at deleted_on id name updated_at updated_on]
      expect(RailsAdmin.config(FieldVisibilityTest).list.fields.select(&:visible?).collect(&:name)).to match_array %i[_id created_at created_on deleted_at deleted_on id name updated_at updated_on]
      expect(RailsAdmin.config(FieldVisibilityTest).edit.fields.select(&:visible?).collect(&:name)).to match_array [:name]
      expect(RailsAdmin.config(FieldVisibilityTest).show.fields.select(&:visible?).collect(&:name)).to match_array [:name]
    end
  end

  describe '#allowed_methods' do
    it 'includes method_name' do
      RailsAdmin.config do |config|
        config.model Team do
          field :name
        end
      end

      expect(RailsAdmin.config(Team).field(:name).allowed_methods).to eq [:name]
    end
  end
end
