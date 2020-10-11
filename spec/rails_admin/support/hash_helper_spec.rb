# encoding: utf-8

require 'spec_helper'

RSpec.describe RailsAdmin::HashHelper do
  let(:hash) do
    {
      'subject' => 'Test',
      'user' => {
        name: 'Dirk',
        'title' => 'Holistic Detective',
        'clients' => [
          {name: 'Zaphod'},
          {'name' => 'Arthur'},
        ],
      },
    }
  end

  describe 'symbolize' do
    let(:symbolized_hash) { RailsAdmin::HashHelper.symbolize(hash) }

    it 'symbolizes top-level hash keys' do
      %i[subject user].each do |key|
        expect(symbolized_hash.keys).to include(key)
      end
    end

    it 'symbolizes nested hashes' do
      %i[name title clients].each do |key|
        expect(symbolized_hash[:user].keys).to include(key)
      end
    end

    it 'symbolizes nested hashes inside of array values' do
      clients = symbolized_hash[:user][:clients]
      expect(clients.length).to eq(2)
      expect(clients[0][:name]).to eq(:Zaphod)
      expect(clients[1][:name]).to eq(:Arthur)
    end
  end
end
