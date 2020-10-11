require 'spec_helper'

RSpec.describe RailsAdmin::Config::Actions do
  describe 'default' do
    it 'is as before' do
      expect(RailsAdmin::Config::Actions.all.collect(&:key)).to eq(%i[dashboard index show new edit export delete bulk_delete history_show history_index show_in_app])
    end
  end

  describe 'find' do
    it 'finds by custom key' do
      RailsAdmin.config do |config|
        config.actions do
          dashboard do
            custom_key :custom_dashboard
          end

          collection :custom_collection, :index

          show
        end
      end

      expect(RailsAdmin::Config::Actions.find(:custom_dashboard)).to be_a(RailsAdmin::Config::Actions::Dashboard)
      expect(RailsAdmin::Config::Actions.find(:custom_collection)).to be_a(RailsAdmin::Config::Actions::Index)
      expect(RailsAdmin::Config::Actions.find(:show)).to be_a(RailsAdmin::Config::Actions::Show)
    end

    it 'returns nil when no action is found by the custom key' do
      expect(RailsAdmin::Config::Actions.find(:non_existent_action_key)).to be_nil
    end

    it 'returns visible action passing binding if controller binding is given, and pass action visible or not if no' do
      RailsAdmin.config do |config|
        config.actions do
          root :custom_root do
            visible do
              bindings[:controller] == 'controller'
            end
          end
        end
      end
      expect(RailsAdmin::Config::Actions.find(:custom_root)).to be_a(RailsAdmin::Config::Actions::Base)
      expect(RailsAdmin::Config::Actions.find(:custom_root, controller: 'not_controller')).to be_nil
      expect(RailsAdmin::Config::Actions.find(:custom_root, controller: 'controller')).to be_a(RailsAdmin::Config::Actions::Base)
    end

    it "ignores bindings[:abstract_model] visibility while checking action\'s visibility" do
      RailsAdmin.config Team do
        hide
      end

      expect(RailsAdmin::Config::Actions.find(:index, controller: double(authorized?: true), abstract_model: RailsAdmin::AbstractModel.new(Comment))).to be_a(RailsAdmin::Config::Actions::Index) # decoy
      expect(RailsAdmin::Config::Actions.find(:index, controller: double(authorized?: true), abstract_model: RailsAdmin::AbstractModel.new(Team))).to be_a(RailsAdmin::Config::Actions::Index)
    end

    it "checks bindings[:abstract_model] presence while checking action\'s visibility" do
      RailsAdmin.config do |config|
        config.excluded_models << Team
      end
      expect(RailsAdmin::Config::Actions.find(:index, controller: double(authorized?: true), abstract_model: RailsAdmin::AbstractModel.new(Comment))).to be_a(RailsAdmin::Config::Actions::Index) # decoy
      expect(RailsAdmin::Config::Actions.find(:index, controller: double(authorized?: true), abstract_model: RailsAdmin::AbstractModel.new(Team))).to be_nil
    end
  end

  describe 'all' do
    it 'returns all defined actions' do
      RailsAdmin.config do |config|
        config.actions do
          dashboard
          index
        end
      end

      expect(RailsAdmin::Config::Actions.all.collect(&:key)).to eq(%i[dashboard index])
    end

    it 'restricts by scope' do
      RailsAdmin.config do |config|
        config.actions do
          root :custom_root
          collection :custom_collection
          member :custom_member
        end
      end
      expect(RailsAdmin::Config::Actions.all(:root).collect(&:key)).to eq([:custom_root])
      expect(RailsAdmin::Config::Actions.all(:collection).collect(&:key)).to eq([:custom_collection])
      expect(RailsAdmin::Config::Actions.all(:member).collect(&:key)).to eq([:custom_member])
    end

    it 'returns all visible actions passing binding if controller binding is given, and pass all actions if no' do
      RailsAdmin.config do |config|
        config.actions do
          root :custom_root do
            visible do
              bindings[:controller] == 'controller'
            end
          end
        end
      end
      expect(RailsAdmin::Config::Actions.all(:root).collect(&:custom_key)).to eq([:custom_root])
      expect(RailsAdmin::Config::Actions.all(:root, controller: 'not_controller').collect(&:custom_key)).to eq([])
      expect(RailsAdmin::Config::Actions.all(:root, controller: 'controller').collect(&:custom_key)).to eq([:custom_root])
    end
  end

  describe 'customized through DSL' do
    it 'adds the one asked' do
      RailsAdmin.config do |config|
        config.actions do
          dashboard
          index
          show
        end
      end

      expect(RailsAdmin::Config::Actions.all.collect(&:key)).to eq(%i[dashboard index show])
    end

    it 'allows to customize the custom_key when customizing an existing action' do
      RailsAdmin.config do |config|
        config.actions do
          dashboard do
            custom_key :my_dashboard
          end
        end
      end
      expect(RailsAdmin::Config::Actions.all.collect(&:custom_key)).to eq([:my_dashboard])
      expect(RailsAdmin::Config::Actions.all.collect(&:key)).to eq([:dashboard])
    end

    it 'allows to change the key and the custom_key when subclassing an existing action' do
      RailsAdmin.config do |config|
        config.actions do
          root :my_dashboard_key, :dashboard do
            custom_key :my_dashboard_custom_key
          end
        end
      end
      expect(RailsAdmin::Config::Actions.all.collect(&:custom_key)).to eq([:my_dashboard_custom_key])
      expect(RailsAdmin::Config::Actions.all.collect(&:key)).to eq([:my_dashboard_key])
      expect(RailsAdmin::Config::Actions.all.collect(&:class)).to eq([RailsAdmin::Config::Actions::Dashboard])
    end

    it 'does not add the same custom_key twice' do
      expect do
        RailsAdmin.config do |config|
          config.actions do
            dashboard
            dashboard
          end
        end
      end.to raise_error('Action dashboard already exists. Please change its custom key.')

      expect do
        RailsAdmin.config do |config|
          config.actions do
            index
            collection :index
          end
        end
      end.to raise_error('Action index already exists. Please change its custom key.')
    end

    it 'adds the same key with different custom key' do
      RailsAdmin.config do |config|
        config.actions do
          dashboard
          dashboard do
            custom_key :my_dashboard
          end
        end
      end

      expect(RailsAdmin::Config::Actions.all.collect(&:custom_key)).to eq(%i[dashboard my_dashboard])
      expect(RailsAdmin::Config::Actions.all.collect(&:key)).to eq(%i[dashboard dashboard])
    end
  end
end
