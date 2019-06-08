require 'spec_helper'
require 'rails_admin/adapters/mongoid/abstract_object'

describe 'RailsAdmin::Adapters::Mongoid::AbstractObject', mongoid: true do
  before do
    @players = FactoryBot.create_list :player, 3
    @draft = FactoryBot.create :draft
    @team = RailsAdmin::Adapters::Mongoid::AbstractObject.new FactoryBot.create :team
  end

  describe 'references_many association' do
    it 'supports retrieval of ids through foo_ids' do
      expect(@team.player_ids).to eq([])
      player = FactoryBot.create :player, team: @team
      expect(@team.player_ids).to eq([player.id])
    end

    it 'supports assignment of items through foo_ids=' do
      expect(@team.players).to eq([])
      @team.player_ids = @players.collect(&:id)
      @team.reload
      expect(@team.players.collect(&:id)).to match_array @players.collect(&:id)
    end

    it 'skips invalid id on assignment through foo_ids=' do
      @team.player_ids = @players.collect { |item| item.id.to_s }.unshift('4f431021dcf2310db7000006')
      @team.reload
      @players.each(&:reload)
      expect(@team.players.collect(&:id)).to match_array @players.collect(&:id)
    end

    describe "model's custom setter" do
      before do
        Team.class_eval do
          def player_ids=(players_ids)
            self.custom_field = players_ids * ', '
          end
        end
      end

      after do
        Team.class_eval do
          undef player_ids=
        end
      end

      it 'have been called' do
        expect(@team.custom_field).to eq(nil)
        @team.player_ids = @players.collect(&:id)
        expect(@team.custom_field).to eq(@players.collect(&:id) * ', ')
      end
    end

    describe 'supports assignment of items through <foreign_key>=' do
      it 'supports foreign_key accessor' do
        @book = FactoryBot.create :book
        @authors = FactoryBot.create_list(:author, 3)
        @book.people = @authors.collect(&:name)
        expect(@book.people).to eq(@authors.collect(&:name))
        expect(@book.authors).to eq(@authors)
      end
    end
  end

  describe 'references_one association' do
    describe "model's custom setter" do
      before do
        Team.class_eval do
          def draft_id=(draft_id)
            self.custom_field = draft_id.to_s
          end
        end
      end

      after do
        Team.class_eval do
          undef draft_id=
        end
      end

      it 'have been called' do
        expect(@team.custom_field).to eq(nil)
        @team.draft_id = @draft.id
        expect(@team.custom_field).to eq(@draft.id.to_s)
      end
    end
  end
end
