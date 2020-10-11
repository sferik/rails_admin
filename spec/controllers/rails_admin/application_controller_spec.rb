require 'spec_helper'

RSpec.describe RailsAdmin::ApplicationController, type: :controller do
  describe '#to_model_name' do
    it 'works with modules' do
      expect(controller.to_model_name('conversations~conversation')).to eq('Conversations::Conversation')
    end
  end

  describe 'helper method _get_plugin_name' do
    it 'works by default' do
      expect(controller.send(:_get_plugin_name)).to eq(['Dummy App', 'Admin'])
    end

    it 'works for static names' do
      RailsAdmin.config do |config|
        config.main_app_name = %w[static value]
      end
      expect(controller.send(:_get_plugin_name)).to eq(%w[static value])
    end

    it 'works for dynamic names in the controller context' do
      RailsAdmin.config do |config|
        config.main_app_name = proc { |controller| [Rails.application.engine_name.try(:titleize), controller.params[:action].titleize] }
      end
      controller.params[:action] = 'dashboard'
      expect(controller.send(:_get_plugin_name)).to eq(['Dummy App Application', 'Dashboard'])
    end
  end

  describe '#_current_user' do
    it 'is public' do
      expect { controller._current_user }.not_to raise_error
    end
  end

  describe '#rails_admin_controller?' do
    it 'returns true' do
      expect(controller.send(:rails_admin_controller?)).to be true
    end
  end
end
