# Configure Rails Envinronment
ENV['RAILS_ENV'] = 'test'
CI_ORM = (ENV['CI_ORM'] || :active_record).to_sym
CI_TARGET_ORMS = %i[active_record mongoid].freeze
PK_COLUMN = {active_record: :id, mongoid: :_id}[CI_ORM]

require 'simplecov'
require 'coveralls'

SimpleCov.formatters = [SimpleCov::Formatter::HTMLFormatter, Coveralls::SimpleCov::Formatter]

SimpleCov.start do
  add_filter '/spec/'
  add_filter '/vendor/bundle/'
  minimum_coverage(CI_ORM == :mongoid ? 90.05 : 91.21)
end

require File.expand_path('dummy_app/config/environment', __dir__)

require 'rspec/rails'
require 'factory_bot'
require 'factories'
require 'policies'
require 'database_cleaner'
require "orm/#{CI_ORM}"

Dir[File.expand_path('support/**/*.rb', __dir__),
    File.expand_path('shared_examples/**/*.rb', __dir__)].sort.each { |f| require f }

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

  config.before do |example|
    DatabaseCleaner.strategy = (CI_ORM == :mongoid || example.metadata[:js]) ? :truncation : :transaction # rubocop:disable Style/TernaryParentheses

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
