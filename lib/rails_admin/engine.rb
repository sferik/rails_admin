require 'jquery-rails'
require 'jquery-ui-rails'
require 'kaminari'
require 'nested_form'
require 'rack-pjax'
require 'rails'
require 'rails_admin'
require 'remotipart'

module RailsAdmin
  class Engine < Rails::Engine
    isolate_namespace RailsAdmin

    config.action_dispatch.rescue_responses['RailsAdmin::ActionNotAllowed'] = :forbidden

    initializer 'RailsAdmin precompile hook', group: :all do |app|
      app.config.assets.precompile += %w[
        rails_admin/rails_admin.js
        rails_admin/rails_admin.css
        rails_admin/jquery.colorpicker.js
        rails_admin/jquery.colorpicker.css
      ]
    end

    initializer 'RailsAdmin setup middlewares' do |app|
      app.config.middleware.use Rack::Pjax
    end

    initializer 'RailsAdmin reload config in development' do
      if Rails.application.config.cache_classes
        if defined?(ActiveSupport::Reloader)
          ActiveSupport::Reloader.before_class_unload do
            RailsAdmin::Config.reset_all_models
          end
          # else
          # For Rails 4 not implemented
        end
      end
    end

    rake_tasks do
      Dir[File.join(File.dirname(__FILE__), '../tasks/*.rake')].each { |f| load f }
    end

    # Check for required middlewares, users may forget to use them in Rails API mode
    config.after_initialize do |app|
      has_session_store = app.config.middleware.to_a.any? do |m|
        m.klass.try(:<=, ActionDispatch::Session::AbstractStore) ||
          m.klass.name =~ /^ActionDispatch::Session::/
      end
      loaded = app.config.middleware.to_a.map(&:name)
      required = %w[ActionDispatch::Cookies ActionDispatch::Flash Rack::MethodOverride]
      missing = required - loaded
      unless missing.empty? && has_session_store
        configs = missing.map { |m| "config.middleware.use #{m}" }
        configs << "config.middleware.use #{app.config.session_store.try(:name) || 'ActionDispatch::Session::CookieStore'}, #{app.config.session_options}" unless has_session_store
        raise <<-EOM
Required middlewares for RailsAdmin are not added
To fix this, add

  #{configs.join("\n  ")}

to config/application.rb.
        EOM
      end
    end
  end
end
