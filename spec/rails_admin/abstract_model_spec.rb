require 'spec_helper'

RSpec.describe RailsAdmin::AbstractModel do
  describe '.all' do
    it 'returns abstract models for all models' do
      expect(RailsAdmin::AbstractModel.all.map(&:model)).to include Player, Team
    end

    it 'does not pick up a model without table', active_record: true do
      expect(RailsAdmin::AbstractModel.all.map(&:model)).not_to include WithoutTable
    end
  end

  describe '#to_s' do
    it 'returns model\'s name' do
      expect(RailsAdmin::AbstractModel.new(Cms::BasicPage).to_s).to eq Cms::BasicPage.to_s
    end
  end

  describe '#to_param' do
    it 'turns namespaces into prefixes with ~' do
      expect(RailsAdmin::AbstractModel.new('Cms::BasicPage').to_param).to eq('cms~basic_page')
    end
  end

  describe 'filters' do
    before do
      @abstract_model = RailsAdmin::AbstractModel.new('FieldTest')
    end

    context 'ActiveModel::ForbiddenAttributesProtection' do
      it 'is present' do
        @abstract_model.model.ancestors.collect(&:to_s).include?('ActiveModel::ForbiddenAttributesProtection')
      end
    end

    context 'on ActiveRecord native enum', active_record: true do
      shared_examples 'filter on enum' do
        before do
          %w[S M L].each do |size|
            FactoryBot.create(:field_test, string_enum_field: size)
          end

          %w[small medium large].each do |size|
            FactoryBot.create(:field_test, integer_enum_field: size)
          end
        end
        let(:model) { RailsAdmin::AbstractModel.new('FieldTest') }
        let(:filters) { {enum_field => {'1' => {v: filter_value, o: 'is'}}} }
        subject(:elements) {  model.all(filters: filters) }

        it 'lists elements by value' do
          expect(elements.count).to eq(expected_elements_count)
          expect(elements.map(&enum_field.to_sym)).to all(eq(enum_label))
        end
      end

      context 'when enum is integer enum' do
        it_behaves_like 'filter on enum' do
          let(:filter_value) { 0 }
          let(:enum_field) { 'integer_enum_field' }
          let(:enum_label) { 'small' }
          let(:expected_elements_count) { 1 }
        end
      end

      context 'when enum is string enum where label <> value' do
        it_behaves_like 'filter on enum' do
          let(:filter_value) { 's' }
          let(:enum_field) { 'string_enum_field' }
          let(:enum_label) { 'S' }
          let(:expected_elements_count) { 1 }
        end
      end
    end

    context 'on dates with :en locale' do
      before do
        [Date.new(2012, 1, 1), Date.new(2012, 1, 2), Date.new(2012, 1, 3), Date.new(2012, 1, 4)].each do |date|
          FactoryBot.create(:field_test, date_field: date)
        end
      end

      it 'lists elements within outbound limits' do
        expect(@abstract_model.all(filters: {'date_field' => {'1' => {v: ['', 'January 02, 2012', 'January 03, 2012'], o: 'between'}}}).count).to eq(2)
        expect(@abstract_model.all(filters: {'date_field' => {'1' => {v: ['', 'January 02, 2012', 'January 02, 2012'], o: 'between'}}}).count).to eq(1)
        expect(@abstract_model.all(filters: {'date_field' => {'1' => {v: ['', 'January 03, 2012', ''], o: 'between'}}}).count).to eq(2)
        expect(@abstract_model.all(filters: {'date_field' => {'1' => {v: ['', '', 'January 02, 2012'], o: 'between'}}}).count).to eq(2)
        expect(@abstract_model.all(filters: {'date_field' => {'1' => {v: ['January 02, 2012'], o: 'default'}}}).count).to eq(1)
      end
    end

    context 'on datetimes with :en locale' do
      before do
        I18n.locale = :en
        FactoryBot.create(:field_test, datetime_field: Time.zone.local(2012, 1, 1, 23, 59, 59))
        FactoryBot.create(:field_test, datetime_field: Time.zone.local(2012, 1, 2, 0, 0, 0))
        FactoryBot.create(:field_test, datetime_field: Time.zone.local(2012, 1, 3, 23, 59, 59))

        # TODO: Mongoid 3.0.0 mysteriously expands the range of inclusion slightly...
        if defined?(Mongoid) && Mongoid::VERSION >= '3.0.0'
          FactoryBot.create(:field_test, datetime_field: Time.zone.local(2012, 1, 4, 0, 0, 1))
        else
          FactoryBot.create(:field_test, datetime_field: Time.zone.local(2012, 1, 4, 0, 0, 0))
        end
      end

      it 'lists elements within outbound limits' do
        expect(@abstract_model.all(filters: {'datetime_field' => {'1' => {v: ['', 'January 02, 2012 12:00', 'January 03, 2012 12:00'], o: 'between'}}}).count).to eq(2)
        expect(@abstract_model.all(filters: {'datetime_field' => {'1' => {v: ['', 'January 02, 2012 12:00', 'January 02, 2012 12:00'], o: 'between'}}}).count).to eq(1)
        expect(@abstract_model.all(filters: {'datetime_field' => {'1' => {v: ['', 'January 03, 2012 12:00', ''], o: 'between'}}}).count).to eq(2)
        expect(@abstract_model.all(filters: {'datetime_field' => {'1' => {v: ['', '', 'January 02, 2012 12:00'], o: 'between'}}}).count).to eq(2)
        expect(@abstract_model.all(filters: {'datetime_field' => {'1' => {v: ['January 02, 2012 12:00'], o: 'default'}}}).count).to eq(1)
      end
    end
  end

  context 'with Kaminari' do
    before do
      @paged = Player.page(1)
      Kaminari.config.page_method_name = :per_page_kaminari
      @abstract_model = RailsAdmin::AbstractModel.new('Player')
    end

    after do
      Kaminari.config.page_method_name = :page
    end

    it "supports pagination when Kaminari's page_method_name is customized" do
      expect(Player).to receive(:per_page_kaminari).once.and_return(@paged)
      @abstract_model.all(sort: PK_COLUMN, page: 1, per: 2)
    end
  end

  describe 'each_associated_children' do
    before do
      @abstract_model = RailsAdmin::AbstractModel.new('Player')
      @draft = FactoryBot.build :draft
      @comments = FactoryBot.build_list :comment, 2
      @player = FactoryBot.build :player, draft: @draft, comments: @comments
    end

    it 'should return has_one and has_many associations with its children' do
      @abstract_model.each_associated_children(@player) do |association, children|
        expect(children).to eq case association.name
                               when :draft
                                 [@draft]
                               when :comments
                                 @comments
                               end
      end
    end
  end
end
