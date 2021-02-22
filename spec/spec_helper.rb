# Configure Rails Envinronment
ENV['RAILS_ENV'] = 'test'
CI_ORM = (ENV['CI_ORM'] || :active_record).to_sym
CI_TARGET_ORMS = [:active_record, :mongoid].freeze
PK_COLUMN = {active_record: :id, mongoid: :_id}[CI_ORM]

if RUBY_ENGINE == 'jruby'
  # Workaround for JRuby CI failure https://github.com/jruby/jruby/issues/6547#issuecomment-774104996
  require 'i18n/backend'
  require 'i18n/backend/simple'
end

require 'simplecov'
require 'simplecov-lcov'

SimpleCov.formatters = [SimpleCov::Formatter::HTMLFormatter, SimpleCov::Formatter::LcovFormatter]

SimpleCov.start do
  add_filter '/spec/'
  add_filter '/vendor/bundle/'
  minimum_coverage(CI_ORM == :mongoid ? 90.05 : 91.21)
end

SimpleCov::Formatter::LcovFormatter.config do |c|
  c.report_with_single_file = true
  c.single_report_path = 'coverage/lcov.info'
end

require File.expand_path('../dummy_app/config/environment', __FILE__)

require 'rspec/rails'
require 'factory_bot'
require 'factories'
require 'policies'
require "database_cleaner/#{CI_ORM}"
require "orm/#{CI_ORM}"

Dir[File.expand_path('../support/**/*.rb', __FILE__),
    File.expand_path('../shared_examples/**/*.rb', __FILE__)].each { |f| require f }

ActionMailer::Base.delivery_method = :test
ActionMailer::Base.perform_deliveries = true
ActionMailer::Base.default_url_options[:host] = 'example.com'

Rails.backtrace_cleaner.remove_silencers!

# Don't need passwords in test DB to be secure, but we would like 'em to be
# fast -- and the stretches mechanism is intended to make passwords
# computationally expensive.
module Devise
  module Models
    module DatabaseAuthenticatable
    protected

      def password_digest(password)
        password
      end
    end
  end
end

Devise.setup do |config|
  config.stretches = 0
end

require 'capybara/poltergeist'
Capybara.javascript_driver = :poltergeist
Capybara.server = :webrick

RailsAdmin.setup_all_extensions

RSpec.configure do |config|
  config.expect_with :rspec do |c|
    c.syntax = :expect
  end

  config.disable_monkey_patching!

  config.include RSpec::Matchers
  config.include RailsAdmin::Engine.routes.url_helpers

  config.include Warden::Test::Helpers

  config.include Capybara::DSL, type: :request

  config.verbose_retry = true
  config.display_try_failure_messages = true
  config.around :each, :js do |example|
    example.run_with_retry retry: 2
  end
  config.retry_callback = proc do |example|
    Capybara.reset! if example.metadata[:js]
  end

  config.before do |example|
    DatabaseCleaner.strategy = (CI_ORM == :mongoid || example.metadata[:js]) ? :deletion : :transaction

    DatabaseCleaner.start
    RailsAdmin::Config.reset
    RailsAdmin::AbstractModel.reset
    RailsAdmin::Config.audit_with(:history) if CI_ORM == :active_record
  end

  config.after(:each) do
    Warden.test_reset!
    DatabaseCleaner.clean
  end

  CI_TARGET_ORMS.each do |orm|
    if orm == CI_ORM
      config.filter_run_excluding "skip_#{orm}".to_sym => true
    else
      config.filter_run_excluding orm => true
    end
  end
end
