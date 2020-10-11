require 'spec_helper'

RSpec.describe 'Serialized field', type: :request do
  subject { page }

  context 'with serialized objects' do
    before do
      RailsAdmin.config do |c|
        c.model User do
          configure :roles, :serialized
        end
      end

      @user = FactoryBot.create :user

      visit edit_path(model_name: 'user', id: @user.id)

      fill_in 'user[roles]', with: %(['admin', 'user'])
      click_button 'Save' # first(:button, "Save").click

      @user.reload
    end

    it 'saves the serialized data' do
      expect(@user.roles).to eq(%w[admin user])
    end
  end

  context 'with serialized objects of Mongoid', mongoid: true do
    before do
      @field_test = FactoryBot.create :field_test

      visit edit_path(model_name: 'field_test', id: @field_test.id)
    end

    it 'saves the serialized data' do
      fill_in 'field_test[array_field]', with: '[4, 2]'
      fill_in 'field_test[hash_field]', with: '{ a: 6, b: 2 }'
      click_button 'Save' # first(:button, "Save").click

      @field_test.reload
      expect(@field_test.array_field).to eq([4, 2])
      expect(@field_test.hash_field).to eq('a' => 6, 'b' => 2)
    end

    it 'clears data when empty string is passed' do
      fill_in 'field_test[array_field]', with: ''
      fill_in 'field_test[hash_field]', with: ''
      click_button 'Save' # first(:button, "Save").click

      @field_test.reload
      expect(@field_test.array_field).to eq(nil)
      expect(@field_test.hash_field).to eq(nil)
    end
  end
end
