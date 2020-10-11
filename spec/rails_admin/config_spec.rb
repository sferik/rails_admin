require 'spec_helper'

RSpec.describe RailsAdmin::Config do
  describe '.included_models' do
    it 'only uses included models' do
      RailsAdmin.config.included_models = [Team, League]
      expect(RailsAdmin::AbstractModel.all.collect(&:model)).to eq([League, Team]) # it gets sorted
    end

    it 'does not restrict models if included_models is left empty' do
      RailsAdmin.config.included_models = []
      expect(RailsAdmin::AbstractModel.all.collect(&:model)).to include(Team, League)
    end

    it 'removes excluded models (whitelist - blacklist)' do
      RailsAdmin.config.excluded_models = [Team]
      RailsAdmin.config.included_models = [Team, League]
      expect(RailsAdmin::AbstractModel.all.collect(&:model)).to eq([League])
    end

    it 'always excludes history', active_record: true do
      expect(RailsAdmin::AbstractModel.all.collect(&:model)).not_to include(RailsAdmin::History)
    end

    it 'excluded? returns true for any model not on the list' do
      RailsAdmin.config.included_models = [Team, League]

      team_config = RailsAdmin::AbstractModel.new('Team').config
      fan_config = RailsAdmin::AbstractModel.new('Fan').config

      expect(fan_config).to be_excluded
      expect(team_config).not_to be_excluded
    end
  end

  describe '.add_extension' do
    before do
      silence_warnings do
        RailsAdmin.const_set('EXTENSIONS', [])
      end
    end

    it 'registers the extension with RailsAdmin' do
      RailsAdmin.add_extension(:example, ExampleModule)
      expect(RailsAdmin::EXTENSIONS.count { |name| name == :example }).to eq(1)
    end

    context 'given an extension with an authorization adapter' do
      it 'registers the adapter' do
        RailsAdmin.add_extension(:example, ExampleModule, authorization: true)
        expect(RailsAdmin::AUTHORIZATION_ADAPTERS[:example]).to eq(ExampleModule::AuthorizationAdapter)
      end
    end

    context 'given an extension with an auditing adapter' do
      it 'registers the adapter' do
        RailsAdmin.add_extension(:example, ExampleModule, auditing: true)
        expect(RailsAdmin::AUDITING_ADAPTERS[:example]).to eq(ExampleModule::AuditingAdapter)
      end
    end

    context 'given an extension with a configuration adapter' do
      it 'registers the adapter' do
        RailsAdmin.add_extension(:example, ExampleModule, configuration: true)
        expect(RailsAdmin::CONFIGURATION_ADAPTERS[:example]).to eq(ExampleModule::ConfigurationAdapter)
      end
    end
  end

  describe '.main_app_name' do
    it 'as a default meaningful dynamic value' do
      expect(RailsAdmin.config.main_app_name.call).to eq(['Dummy App', 'Admin'])
    end

    it 'can be configured' do
      RailsAdmin.config do |config|
        config.main_app_name = %w[stati c value]
      end
      expect(RailsAdmin.config.main_app_name).to eq(%w[stati c value])
    end
  end

  describe '.authorize_with' do
    context 'given a key for a extension with authorization' do
      before do
        RailsAdmin.add_extension(:example, ExampleModule, authorization: true)
      end

      it 'initializes the authorization adapter' do
        expect(ExampleModule::AuthorizationAdapter).to receive(:new).with(RailsAdmin::Config)
        RailsAdmin.config do |config|
          config.authorize_with(:example)
        end
        RailsAdmin.config.authorize_with.call
      end

      it 'passes through any additional arguments to the initializer' do
        options = {option: true}
        expect(ExampleModule::AuthorizationAdapter).to receive(:new).with(RailsAdmin::Config, options)
        RailsAdmin.config do |config|
          config.authorize_with(:example, options)
        end
        RailsAdmin.config.authorize_with.call
      end
    end
  end

  describe '.audit_with' do
    context 'given a key for a extension with auditing' do
      before do
        RailsAdmin.add_extension(:example, ExampleModule, auditing: true)
      end

      it 'initializes the auditing adapter' do
        expect(ExampleModule::AuditingAdapter).to receive(:new).with(RailsAdmin::Config)
        RailsAdmin.config do |config|
          config.audit_with(:example)
        end
        RailsAdmin.config.audit_with.call
      end

      it 'passes through any additional arguments to the initializer' do
        options = {option: true}
        expect(ExampleModule::AuditingAdapter).to receive(:new).with(RailsAdmin::Config, options)
        RailsAdmin.config do |config|
          config.audit_with(:example, options)
        end
        RailsAdmin.config.audit_with.call
      end
    end

    context 'given paper_trail as the extension for auditing', active_record: true do
      before do
        class ControllerMock
          def set_paper_trail_whodunnit; end
        end
        module PaperTrail; end
        class Version; end
        RailsAdmin.add_extension(:example, RailsAdmin::Extensions::PaperTrail, auditing: true)
      end

      it 'initializes the auditing adapter' do
        RailsAdmin.config do |config|
          config.audit_with(:example)
        end
        expect { ControllerMock.new.instance_eval(&RailsAdmin.config.audit_with) }.not_to raise_error
      end
    end
  end

  describe '.configure_with' do
    context 'given a key for a extension with configuration' do
      before do
        RailsAdmin.add_extension(:example, ExampleModule, configuration: true)
      end

      it 'initializes configuration adapter' do
        expect(ExampleModule::ConfigurationAdapter).to receive(:new)
        RailsAdmin.config do |config|
          config.configure_with(:example)
        end
      end

      it 'yields the (optionally) provided block, passing the initialized adapter' do
        configurator = nil
        RailsAdmin.config do |config|
          config.configure_with(:example) do |configuration_adapter|
            configurator = configuration_adapter
          end
        end
        expect(configurator).to be_a(ExampleModule::ConfigurationAdapter)
      end
    end
  end

  describe '.config' do
    context '.default_search_operator' do
      it 'sets the default_search_operator' do
        RailsAdmin.config do |config|
          config.default_search_operator = 'starts_with'
        end
        expect(RailsAdmin::Config.default_search_operator).to eq('starts_with')
      end

      it 'errors on unrecognized search operator' do
        expect do
          RailsAdmin.config do |config|
            config.default_search_operator = 'random'
          end
        end.to raise_error(ArgumentError, "Search operator 'random' not supported")
      end

      it "defaults to 'default'" do
        expect(RailsAdmin::Config.default_search_operator).to eq('default')
      end
    end
  end

  describe '.visible_models' do
    it 'passes controller bindings, find visible models, order them' do
      RailsAdmin.config do |config|
        config.included_models = [Player, Fan, Comment, Team]

        config.model Player do
          hide
        end
        config.model Fan do
          weight(-1)
          show
        end
        config.model Comment do
          visible do
            bindings[:controller]._current_user.role == :admin
          end
        end
        config.model Team do
          visible do
            bindings[:controller]._current_user.role != :admin
          end
        end
      end

      expect(RailsAdmin.config.visible_models(controller: double(_current_user: double(role: :admin), authorized?: true)).collect(&:abstract_model).collect(&:model)).to match_array [Fan, Comment]
    end

    it 'hides unallowed models' do
      RailsAdmin.config do |config|
        config.included_models = [Comment]
      end
      expect(RailsAdmin.config.visible_models(controller: double(authorization_adapter: double(authorized?: true))).collect(&:abstract_model).collect(&:model)).to eq([Comment])
      expect(RailsAdmin.config.visible_models(controller: double(authorization_adapter: double(authorized?: false))).collect(&:abstract_model).collect(&:model)).to eq([])
    end

    it 'does not contain embedded model', mongoid: true do
      RailsAdmin.config do |config|
        config.included_models = [FieldTest, Comment, Embed]
      end

      expect(RailsAdmin.config.visible_models(controller: double(_current_user: double(role: :admin), authorized?: true)).collect(&:abstract_model).collect(&:model)).to match_array [FieldTest, Comment]
    end

    it 'basically does not contain embedded model except model using recursively_embeds_many or recursively_embeds_one', mongoid: true do
      class RecursivelyEmbedsOne
        include Mongoid::Document
        recursively_embeds_one
      end
      class RecursivelyEmbedsMany
        include Mongoid::Document
        recursively_embeds_many
      end
      RailsAdmin.config do |config|
        config.included_models = [FieldTest, Comment, Embed, RecursivelyEmbedsMany, RecursivelyEmbedsOne]
      end
      expect(RailsAdmin.config.visible_models(controller: double(_current_user: double(role: :admin), authorized?: true)).collect(&:abstract_model).collect(&:model)).to match_array [FieldTest, Comment, RecursivelyEmbedsMany, RecursivelyEmbedsOne]
    end
  end

  describe '.models_pool' do
    it 'should not include classnames start with Concerns::' do
      expect(RailsAdmin::Config.models_pool.select { |m| m.match(/^Concerns::/) }).to be_empty
    end
  end

  describe '.parent_controller' do
    it 'uses default class' do
      expect(RailsAdmin.config.parent_controller).to eq '::ActionController::Base'
    end

    it 'uses other class' do
      RailsAdmin.config do |config|
        config.parent_controller = 'TestController'
      end
      expect(RailsAdmin.config.parent_controller).to eq 'TestController'
    end
  end

  describe '.forgery_protection_settings' do
    it 'uses with: :exception by default' do
      expect(RailsAdmin.config.forgery_protection_settings).to eq(with: :exception)
    end

    it 'allows to customize settings' do
      RailsAdmin.config do |config|
        config.forgery_protection_settings = {with: :null_session}
      end
      expect(RailsAdmin.config.forgery_protection_settings).to eq(with: :null_session)
    end
  end

  describe '.model' do
    let(:fields) { described_class.model(Team).fields }
    before do
      described_class.model Team do
        field :players do
          visible false
        end
      end
    end
    context 'when model expanded' do
      before do
        described_class.model(Team) do
          field :fans
        end
      end
      it 'execute all passed blocks' do
        expect(fields.map(&:name)).to match_array %i[players fans]
      end
    end
    context 'when expand redefine behavior' do
      before do
        described_class.model Team do
          field :players
        end
      end
      it 'execute all passed blocks' do
        expect(fields.find { |f| f.name == :players }.visible).to be true
      end
    end
    context 'when model expanded in config' do
      let(:block) { proc { field :players } }
      before do
        allow(block).to receive(:source_location).and_return(['config/initializers/rails_admin.rb'])
        described_class.model(Team, &block)
      end
      it 'executes first' do
        expect(fields.find { |f| f.name == :players }.visible).to be false
      end
    end
  end

  describe 'field types code reloading' do
    before { Rails.application.config.cache_classes = false }
    after { Rails.application.config.cache_classes = true }

    let(:config) { described_class.model(Team) }
    let(:fields) { described_class.model(Team).edit.fields }

    let(:team_config) do
      proc do
        field :id
        field :wins, :boolean
      end
    end

    let(:team_config2) do
      proc do
        field :wins, :toggle
      end
    end

    let(:team_config3) do
      proc do
        field :wins
      end
    end

    it 'allows code reloading' do
      Team.send(:rails_admin, &team_config)

      # This simulates the way RailsAdmin really does it
      config.edit.send(:_fields, true)

      module RailsAdmin
        module Config
          module Fields
            module Types
              class Toggle < RailsAdmin::Config::Fields::Base
                RailsAdmin::Config::Fields::Types.register(self)
              end
            end
          end
        end
      end
      Team.send(:rails_admin, &team_config2)
      expect(fields.map(&:name)).to match_array %i[id wins]
    end

    if defined?(ActiveSupport::Reloader)
      it 'updates model config when reloading code for rails 5' do
        Team.send(:rails_admin, &team_config)

        # this simulates rails code reloading
        RailsAdmin::Engine.initializers.select do |i|
          i.name == 'RailsAdmin reload config in development'
        end.first.block.call
        Rails.application.executor.wrap do
          ActiveSupport::Reloader.new.tap(&:class_unload!).complete!
        end

        Team.send(:rails_admin, &team_config3)
        expect(fields.map(&:name)).to match_array %i[wins]
      end
    end
  end
end

module ExampleModule
  class AuthorizationAdapter; end
  class ConfigurationAdapter; end
  class AuditingAdapter; end
end
