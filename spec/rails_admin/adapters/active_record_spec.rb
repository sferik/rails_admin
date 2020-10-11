require 'spec_helper'
require 'timecop'

RSpec.describe 'RailsAdmin::Adapters::ActiveRecord', active_record: true do
  let(:like) do
    if %w[postgresql postgis].include? ::ActiveRecord::Base.configurations[Rails.env]['adapter']
      '(field ILIKE ?)'
    else
      '(LOWER(field) LIKE ?)'
    end
  end

  def predicates_for(scope)
    scope.where_clause.instance_variable_get(:@predicates)
  end

  describe '#associations' do
    it 'returns Association class' do
      expect(RailsAdmin::AbstractModel.new(Player).associations.first).
        to be_a_kind_of RailsAdmin::Adapters::ActiveRecord::Association
    end
  end

  describe '#properties' do
    it 'returns Property class' do
      expect(RailsAdmin::AbstractModel.new(Player).properties.first).
        to be_a_kind_of RailsAdmin::Adapters::ActiveRecord::Property
    end
  end

  describe '#base_class' do
    it 'returns inheritance base class' do
      expect(RailsAdmin::AbstractModel.new(Hardball).base_class).to eq Ball
    end
  end

  describe 'data access methods' do
    let(:abstract_model) { RailsAdmin::AbstractModel.new('Player') }

    before do
      @players = FactoryBot.create_list(:player, 3) + [
        # Multibyte players
        FactoryBot.create(:player, name: 'Антоха'),
        FactoryBot.create(:player, name: 'Петруха'),
      ]
    end

    it '#new returns instance of AbstractObject' do
      expect(abstract_model.new.object).to be_instance_of(Player)
    end

    it '#get returns instance of AbstractObject' do
      expect(abstract_model.get(@players.first.id).object).to eq(@players.first)
    end

    it '#get returns nil when id does not exist' do
      expect(abstract_model.get('abc')).to be_nil
    end

    it '#first returns a player' do
      expect(@players).to include abstract_model.first
    end

    describe '#count' do
      it 'returns count of items' do
        expect(abstract_model.count).to eq(@players.count)
      end

      context 'when default-scoped with select' do
        before do
          class PlayerWithDefaultScope < Player
            self.table_name = 'players'
            default_scope { select(:id, :name) }
          end
        end
        let(:abstract_model) { RailsAdmin::AbstractModel.new('PlayerWithDefaultScope') }

        it 'does not break' do
          expect(abstract_model.count).to eq(@players.count)
        end
      end
    end

    it '#destroy destroys multiple items' do
      abstract_model.destroy(@players[0..1])
      expect(Player.all).to eq(@players[2..-1])
    end

    it '#where returns filtered results' do
      expect(abstract_model.where(name: @players.first.name)).to eq([@players.first])
    end

    describe '#all' do
      it 'works without options' do
        expect(abstract_model.all).to match_array @players
      end

      it 'supports eager loading' do
        expect(abstract_model.all(include: :team).includes_values).to eq([:team])
      end

      it 'supports limiting' do
        expect(abstract_model.all(limit: 2).size).to eq(2)
      end

      it 'supports retrieval by bulk_ids' do
        expect(abstract_model.all(bulk_ids: @players[0..1].collect(&:id))).to match_array @players[0..1]
      end

      it 'supports pagination' do
        expect(abstract_model.all(sort: 'id', page: 2, per: 1)).to eq(@players[-2, 1])
        expect(abstract_model.all(sort: 'id', page: 1, per: 2)).to eq(@players[-2, 2].reverse)
      end

      it 'supports ordering' do
        expect(abstract_model.all(sort: 'id', sort_reverse: true)).to eq(@players.sort)
      end

      it 'supports querying' do
        results = abstract_model.all(query: @players[1].name)
        expect(results).to eq(@players[1..1])
      end

      it 'supports multibyte querying' do
        unless ::ActiveRecord::Base.configurations[Rails.env]['adapter'] == 'sqlite3'
          results = abstract_model.all(query: @players[4].name)
          expect(results).to eq(@players[4, 1])
        end
      end

      it 'supports filtering' do
        expect(abstract_model.all(filters: {'name' => {'0000' => {o: 'is', v: @players[1].name}}})).to eq(@players[1..1])
      end
    end
  end

  describe '#query_scope' do
    let(:abstract_model) { RailsAdmin::AbstractModel.new('Team') }

    before do
      @teams = [{}, {name: 'somewhere foos'}, {manager: 'foo junior'}].
               collect { |h| FactoryBot.create :team, h }
    end

    it 'makes correct query' do
      expect(abstract_model.all(query: 'foo')).to match_array @teams[1..2]
    end

    context "when field's searchable_columns is empty" do
      before do
        RailsAdmin.config do |c|
          c.model Team do
            field :players
          end
        end
      end

      it 'does not break' do
        expect { abstract_model.all(query: 'foo') }.not_to raise_error
      end
    end

    context 'when parsing is not idempotent' do
      before do
        RailsAdmin.config do |c|
          c.model Team do
            field :name do
              def parse_value(value)
                "#{value}s"
              end
            end
          end
        end
      end

      it 'parses value only once' do
        expect(abstract_model.all(query: 'foo')).to match_array @teams[1]
      end
    end
  end

  describe '#filter_scope' do
    let(:abstract_model) { RailsAdmin::AbstractModel.new('Team') }

    before do
      @division = FactoryBot.create :division, name: 'bar division'
      @teams = [{}, {division: @division}, {name: 'somewhere foos', division: @division}, {name: 'nowhere foos'}].
               collect { |h| FactoryBot.create :team, h }
    end

    context 'without configuration' do
      before do
        allow(Rails.configuration).to receive(:database_configuration) { nil }
      end

      after do
        allow(Rails.configuration).to receive(:database_configuration).and_call_original
      end

      it 'does not raise error' do
        expect { abstract_model.all(filters: {'name' => {'0000' => {o: 'like', v: 'foo'}}}) }.to_not raise_error
      end
    end

    it 'makes correct query' do
      expect(abstract_model.all(filters: {'name' => {'0000' => {o: 'like', v: 'foo'}}, 'division' => {'0001' => {o: 'like', v: 'bar'}}}, include: :division)).to eq([@teams[2]])
    end

    context 'when parsing is not idempotent' do
      before do
        RailsAdmin.config do |c|
          c.model Team do
            field :name do
              def parse_value(value)
                "some#{value}"
              end
            end
          end
        end
      end

      it 'parses value only once' do
        expect(abstract_model.all(filters: {'name' => {'0000' => {o: 'like', v: 'where'}}})).to match_array @teams[2]
      end
    end

    context 'when a default_search_operator is set' do
      before do
        RailsAdmin.config do |c|
          c.default_search_operator = 'starts_with'
        end
      end

      it 'only matches on prefix' do
        # Specified operator is honored and matches
        expect(abstract_model.all(filters: {'name' => {'0000' => {o: 'like', v: 'where'}}})).to match_array @teams[2..3]

        # No operator falls back to the default_search_operator(starts_with) and doesn't match NON-PREFIX
        expect(abstract_model.all(filters: {'name' => {'0000' => {v: 'where'}}})).to be_empty

        # No operator falls back to the default_search_operator(starts_with) and doesn't match NON-PREFIX
        expect(abstract_model.all(filters: {'name' => {'0000' => {v: 'somewhere'}}})).to match_array @teams[2]
      end
    end
  end

  describe '#build_statement' do
    let(:abstract_model) { RailsAdmin::AbstractModel.new('FieldTest') }

    def build_statement(type, value, operator)
      abstract_model.send(:build_statement, :field, type, value, operator)
    end

    it "ignores '_discard' operator or value" do
      [['_discard', ''], ['', '_discard']].each do |value, operator|
        expect(build_statement(:string, value, operator)).to be_nil
      end
    end

    describe 'string type queries' do
      it 'supports string type query' do
        expect(build_statement(:string, '', nil)).to be_nil
        expect(build_statement(:string, 'foo', 'was')).to be_nil
        expect(build_statement(:string, 'foo', 'default')).to eq([like, '%foo%'])
        expect(build_statement(:string, 'foo', 'like')).to eq([like, '%foo%'])
        expect(build_statement(:string, 'foo', 'starts_with')).to eq([like, 'foo%'])
        expect(build_statement(:string, 'foo', 'ends_with')).to eq([like, '%foo'])
        expect(build_statement(:string, 'foo', 'is')).to eq(['(field = ?)', 'foo'])
      end

      it 'performs case-insensitive searches' do
        unless %w[postgresql postgis].include?(::ActiveRecord::Base.configurations[Rails.env]['adapter'])
          expect(build_statement(:string, 'foo', 'default')).to eq([like, '%foo%'])
          expect(build_statement(:string, 'FOO', 'default')).to eq([like, '%foo%'])
        end
      end

      it 'chooses like statement in per-model basis' do
        allow(FieldTest.connection).to receive(:adapter_name).and_return('postgresql')
        expect(build_statement(:string, 'foo', 'default')).to eq(['(field ILIKE ?)', '%foo%'])
        allow(FieldTest.connection).to receive(:adapter_name).and_return('sqlite3')
        expect(build_statement(:string, 'foo', 'default')).to eq(['(LOWER(field) LIKE ?)', '%foo%'])
      end

      it "supports '_blank' operator" do
        [['_blank', ''], ['', '_blank']].each do |value, operator|
          expect(build_statement(:string, value, operator)).to eq(["(field IS NULL OR field = '')"])
        end
      end

      it "supports '_present' operator" do
        [['_present', ''], ['', '_present']].each do |value, operator|
          expect(build_statement(:string, value, operator)).to eq(["(field IS NOT NULL AND field != '')"])
        end
      end

      it "supports '_null' operator" do
        [['_null', ''], ['', '_null']].each do |value, operator|
          expect(build_statement(:string, value, operator)).to eq(['(field IS NULL)'])
        end
      end

      it "supports '_not_null' operator" do
        [['_not_null', ''], ['', '_not_null']].each do |value, operator|
          expect(build_statement(:string, value, operator)).to eq(['(field IS NOT NULL)'])
        end
      end

      it "supports '_empty' operator" do
        [['_empty', ''], ['', '_empty']].each do |value, operator|
          expect(build_statement(:string, value, operator)).to eq(["(field = '')"])
        end
      end

      it "supports '_not_empty' operator" do
        [['_not_empty', ''], ['', '_not_empty']].each do |value, operator|
          expect(build_statement(:string, value, operator)).to eq(["(field != '')"])
        end
      end
    end

    describe 'boolean type queries' do
      it 'supports boolean type query' do
        %w[false f 0].each do |value|
          expect(build_statement(:boolean, value, nil)).to eq(['(field IS NULL OR field = ?)', false])
        end
        %w[true t 1].each do |value|
          expect(build_statement(:boolean, value, nil)).to eq(['(field = ?)', true])
        end
        expect(build_statement(:boolean, 'word', nil)).to be_nil
      end

      it "supports '_blank' operator" do
        [['_blank', ''], ['', '_blank']].each do |value, operator|
          expect(build_statement(:boolean, value, operator)).to eq(['(field IS NULL)'])
        end
      end

      it "supports '_present' operator" do
        [['_present', ''], ['', '_present']].each do |value, operator|
          expect(build_statement(:boolean, value, operator)).to eq(['(field IS NOT NULL)'])
        end
      end

      it "supports '_null' operator" do
        [['_null', ''], ['', '_null']].each do |value, operator|
          expect(build_statement(:boolean, value, operator)).to eq(['(field IS NULL)'])
        end
      end

      it "supports '_not_null' operator" do
        [['_not_null', ''], ['', '_not_null']].each do |value, operator|
          expect(build_statement(:boolean, value, operator)).to eq(['(field IS NOT NULL)'])
        end
      end

      it "supports '_empty' operator" do
        [['_empty', ''], ['', '_empty']].each do |value, operator|
          expect(build_statement(:boolean, value, operator)).to eq(['(field IS NULL)'])
        end
      end

      it "supports '_not_empty' operator" do
        [['_not_empty', ''], ['', '_not_empty']].each do |value, operator|
          expect(build_statement(:boolean, value, operator)).to eq(['(field IS NOT NULL)'])
        end
      end
    end

    describe 'numeric type queries' do
      it 'supports integer type query' do
        expect(build_statement(:integer, '1', nil)).to eq(['(field = ?)', 1])
        expect(build_statement(:integer, 'word', nil)).to be_nil
        expect(build_statement(:integer, '1', 'default')).to eq(['(field = ?)', 1])
        expect(build_statement(:integer, 'word', 'default')).to be_nil
        expect(build_statement(:integer, '1', 'between')).to eq(['(field = ?)', 1])
        expect(build_statement(:integer, 'word', 'between')).to be_nil
        expect(build_statement(:integer, ['6', '', ''], 'default')).to eq(['(field = ?)', 6])
        expect(build_statement(:integer, ['7', '10', ''], 'default')).to eq(['(field = ?)', 7])
        expect(build_statement(:integer, ['8', '', '20'], 'default')).to eq(['(field = ?)', 8])
        expect(build_statement(:integer, %w[9 10 20], 'default')).to eq(['(field = ?)', 9])
      end

      it 'supports integer type range query' do
        expect(build_statement(:integer, ['', '', ''], 'between')).to be_nil
        expect(build_statement(:integer, ['2', '', ''], 'between')).to be_nil
        expect(build_statement(:integer, ['', '3', ''], 'between')).to eq(['(field >= ?)', 3])
        expect(build_statement(:integer, ['', '', '5'], 'between')).to eq(['(field <= ?)', 5])
        expect(build_statement(:integer, ['', '10', '20'], 'between')).to eq(['(field BETWEEN ? AND ?)', 10, 20])
        expect(build_statement(:integer, %w[15 10 20], 'between')).to eq(['(field BETWEEN ? AND ?)', 10, 20])
        expect(build_statement(:integer, ['', 'word1', ''], 'between')).to be_nil
        expect(build_statement(:integer, ['', '', 'word2'], 'between')).to be_nil
        expect(build_statement(:integer, ['', 'word3', 'word4'], 'between')).to be_nil
      end

      it 'supports both decimal and float type queries' do
        expect(build_statement(:decimal, '1.1', nil)).to eq(['(field = ?)', 1.1])
        expect(build_statement(:decimal, 'word', nil)).to be_nil
        expect(build_statement(:decimal, '1.1', 'default')).to eq(['(field = ?)', 1.1])
        expect(build_statement(:decimal, 'word', 'default')).to be_nil
        expect(build_statement(:decimal, '1.1', 'between')).to eq(['(field = ?)', 1.1])
        expect(build_statement(:decimal, 'word', 'between')).to be_nil
        expect(build_statement(:decimal, ['6.1', '', ''], 'default')).to eq(['(field = ?)', 6.1])
        expect(build_statement(:decimal, ['7.1', '10.1', ''], 'default')).to eq(['(field = ?)', 7.1])
        expect(build_statement(:decimal, ['8.1', '', '20.1'], 'default')).to eq(['(field = ?)', 8.1])
        expect(build_statement(:decimal, ['9.1', '10.1', '20.1'], 'default')).to eq(['(field = ?)', 9.1])
        expect(build_statement(:decimal, ['', '', ''], 'between')).to be_nil
        expect(build_statement(:decimal, ['2.1', '', ''], 'between')).to be_nil
        expect(build_statement(:decimal, ['', '3.1', ''], 'between')).to eq(['(field >= ?)', 3.1])
        expect(build_statement(:decimal, ['', '', '5.1'], 'between')).to eq(['(field <= ?)', 5.1])
        expect(build_statement(:decimal, ['', '10.1', '20.1'], 'between')).to eq(['(field BETWEEN ? AND ?)', 10.1, 20.1])
        expect(build_statement(:decimal, ['15.1', '10.1', '20.1'], 'between')).to eq(['(field BETWEEN ? AND ?)', 10.1, 20.1])
        expect(build_statement(:decimal, ['', 'word1', ''], 'between')).to be_nil
        expect(build_statement(:decimal, ['', '', 'word2'], 'between')).to be_nil
        expect(build_statement(:decimal, ['', 'word3', 'word4'], 'between')).to be_nil

        expect(build_statement(:float, '1.1', nil)).to eq(['(field = ?)', 1.1])
        expect(build_statement(:float, 'word', nil)).to be_nil
        expect(build_statement(:float, '1.1', 'default')).to eq(['(field = ?)', 1.1])
        expect(build_statement(:float, 'word', 'default')).to be_nil
        expect(build_statement(:float, '1.1', 'between')).to eq(['(field = ?)', 1.1])
        expect(build_statement(:float, 'word', 'between')).to be_nil
        expect(build_statement(:float, ['6.1', '', ''], 'default')).to eq(['(field = ?)', 6.1])
        expect(build_statement(:float, ['7.1', '10.1', ''], 'default')).to eq(['(field = ?)', 7.1])
        expect(build_statement(:float, ['8.1', '', '20.1'], 'default')).to eq(['(field = ?)', 8.1])
        expect(build_statement(:float, ['9.1', '10.1', '20.1'], 'default')).to eq(['(field = ?)', 9.1])
        expect(build_statement(:float, ['', '', ''], 'between')).to be_nil
        expect(build_statement(:float, ['2.1', '', ''], 'between')).to be_nil
        expect(build_statement(:float, ['', '3.1', ''], 'between')).to eq(['(field >= ?)', 3.1])
        expect(build_statement(:float, ['', '', '5.1'], 'between')).to eq(['(field <= ?)', 5.1])
        expect(build_statement(:float, ['', '10.1', '20.1'], 'between')).to eq(['(field BETWEEN ? AND ?)', 10.1, 20.1])
        expect(build_statement(:float, ['15.1', '10.1', '20.1'], 'between')).to eq(['(field BETWEEN ? AND ?)', 10.1, 20.1])
        expect(build_statement(:float, ['', 'word1', ''], 'between')).to be_nil
        expect(build_statement(:float, ['', '', 'word2'], 'between')).to be_nil
        expect(build_statement(:float, ['', 'word3', 'word4'], 'between')).to be_nil
      end

      it "supports '_blank' operator" do
        [['_blank', ''], ['', '_blank']].each do |value, operator|
          aggregate_failures do
            expect(build_statement(:integer, value, operator)).to eq(['(field IS NULL)'])
            expect(build_statement(:decimal, value, operator)).to eq(['(field IS NULL)'])
            expect(build_statement(:float, value, operator)).to eq(['(field IS NULL)'])
          end
        end
      end

      it "supports '_present' operator" do
        [['_present', ''], ['', '_present']].each do |value, operator|
          aggregate_failures do
            expect(build_statement(:integer, value, operator)).to eq(['(field IS NOT NULL)'])
            expect(build_statement(:decimal, value, operator)).to eq(['(field IS NOT NULL)'])
            expect(build_statement(:float, value, operator)).to eq(['(field IS NOT NULL)'])
          end
        end
      end

      it "supports '_null' operator" do
        [['_null', ''], ['', '_null']].each do |value, operator|
          aggregate_failures do
            expect(build_statement(:integer, value, operator)).to eq(['(field IS NULL)'])
            expect(build_statement(:decimal, value, operator)).to eq(['(field IS NULL)'])
            expect(build_statement(:float, value, operator)).to eq(['(field IS NULL)'])
          end
        end
      end

      it "supports '_not_null' operator" do
        [['_not_null', ''], ['', '_not_null']].each do |value, operator|
          aggregate_failures do
            expect(build_statement(:integer, value, operator)).to eq(['(field IS NOT NULL)'])
            expect(build_statement(:decimal, value, operator)).to eq(['(field IS NOT NULL)'])
            expect(build_statement(:float, value, operator)).to eq(['(field IS NOT NULL)'])
          end
        end
      end

      it "supports '_empty' operator" do
        [['_empty', ''], ['', '_empty']].each do |value, operator|
          aggregate_failures do
            expect(build_statement(:integer, value, operator)).to eq(['(field IS NULL)'])
            expect(build_statement(:decimal, value, operator)).to eq(['(field IS NULL)'])
            expect(build_statement(:float, value, operator)).to eq(['(field IS NULL)'])
          end
        end
      end

      it "supports '_not_empty' operator" do
        [['_not_empty', ''], ['', '_not_empty']].each do |value, operator|
          aggregate_failures do
            expect(build_statement(:integer, value, operator)).to eq(['(field IS NOT NULL)'])
            expect(build_statement(:decimal, value, operator)).to eq(['(field IS NOT NULL)'])
            expect(build_statement(:float, value, operator)).to eq(['(field IS NOT NULL)'])
          end
        end
      end
    end

    describe 'date type queries' do
      let(:scope) { FieldTest.all }

      it 'supports date type query' do
        expect(predicates_for(abstract_model.send(:filter_scope, scope, 'date_field' => {'1' => {v: ['', 'February 01, 2012', 'March 01, 2012'], o: 'between'}}))).to eq(["(field_tests.date_field BETWEEN '2012-02-01' AND '2012-03-01')"])
        expect(predicates_for(abstract_model.send(:filter_scope, scope, 'date_field' => {'1' => {v: ['', 'March 01, 2012', ''], o: 'between'}}))).to eq(["(field_tests.date_field >= '2012-03-01')"])
        expect(predicates_for(abstract_model.send(:filter_scope, scope, 'date_field' => {'1' => {v: ['', '', 'February 01, 2012'], o: 'between'}}))).to eq(["(field_tests.date_field <= '2012-02-01')"])
        expect(predicates_for(abstract_model.send(:filter_scope, scope, 'date_field' => {'1' => {v: ['February 01, 2012'], o: 'default'}}))).to eq(["(field_tests.date_field BETWEEN '2012-02-01' AND '2012-02-01')"])
      end

      it 'supports datetime type query' do
        expect(predicates_for(abstract_model.send(:filter_scope, scope, 'datetime_field' => {'1' => {v: ['', 'February 01, 2012 12:00', 'March 01, 2012 12:00'], o: 'between'}}))).to eq(predicates_for(scope.where(['(field_tests.datetime_field BETWEEN ? AND ?)', Time.utc(2012, 2, 1), Time.utc(2012, 3, 1).end_of_day])))
        expect(predicates_for(abstract_model.send(:filter_scope, scope, 'datetime_field' => {'1' => {v: ['', 'March 01, 2012 12:00', ''], o: 'between'}}))).to eq(predicates_for(scope.where(['(field_tests.datetime_field >= ?)', Time.utc(2012, 3, 1)])))
        expect(predicates_for(abstract_model.send(:filter_scope, scope, 'datetime_field' => {'1' => {v: ['', '', 'February 01, 2012 12:00'], o: 'between'}}))).to eq(predicates_for(scope.where(['(field_tests.datetime_field <= ?)', Time.utc(2012, 2, 1).end_of_day])))
        expect(predicates_for(abstract_model.send(:filter_scope, scope, 'datetime_field' => {'1' => {v: ['February 01, 2012 12:00'], o: 'default'}}))).to eq(predicates_for(scope.where(['(field_tests.datetime_field BETWEEN ? AND ?)', Time.utc(2012, 2, 1), Time.utc(2012, 2, 1).end_of_day])))
      end
    end

    it 'supports enum type query' do
      expect(build_statement(:enum, '1', nil)).to eq(['(field IN (?))', ['1']])
    end

    describe 'with ActiveRecord native enum' do
      let(:scope) { FieldTest.all }

      it 'supports integer enum type query' do
        expect(predicates_for(abstract_model.send(:filter_scope, scope, 'integer_enum_field' => {'1' => {v: 2, o: 'default'}}))).to eq(predicates_for(scope.where(['(field_tests.integer_enum_field IN (?))', 2])))
      end

      it 'supports string enum type query' do
        expect(predicates_for(abstract_model.send(:filter_scope, scope, 'string_enum_field' => {'1' => {v: 'm', o: 'default'}}))).to eq(predicates_for(scope.where(['(field_tests.string_enum_field IN (?))', 'm'])))
      end
    end

    it 'supports uuid type query' do
      uuid = SecureRandom.uuid
      expect(build_statement(:uuid, uuid, nil)).to eq(['(field = ?)', uuid])
    end
  end

  describe 'model attribute method' do
    let(:abstract_model) { RailsAdmin::AbstractModel.new('Player') }

    it '#scoped returns relation object' do
      expect(abstract_model.scoped).to be_a_kind_of(ActiveRecord::Relation)
    end

    it '#table_name works' do
      expect(abstract_model.table_name).to eq('players')
    end
  end
end
