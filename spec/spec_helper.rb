# -*- encoding : utf-8 -*-
# rubocop:disable AvoidGlobalVars
require 'rubygems'

# Coverage setup
if ENV['COVERAGE'] || ENV['TRAVIS']
  require 'simplecov'

  if ENV['TRAVIS']
    # Store coverage with Coveralls
    require 'coveralls'
    SimpleCov.formatter = Coveralls::SimpleCov::Formatter
  else
    # Output our own report
    SimpleCov.coverage_dir('/spec/coverage')
  end

  SimpleCov.start do
    add_filter '/spec/'
    add_filter '/features/'
    add_filter '/config/'
    add_filter '/db/'
    add_filter '/vendor/bundle/'
    add_filter '.haml'
    add_filter '.erb'
    add_filter '.builder'

    add_group 'Models', '/app/models/'
    add_group 'Controllers', '/app/controllers/'
    add_group 'Domain Logic', '/lib/r_letters'
    add_group 'Jobs', '/lib/jobs'
    add_group 'Mailers', '/app/mailers/'
    add_group 'Administration', '/app/admin/'
    add_group 'Core Extensions', '/lib/core_ext'
  end
end

# Standard setup for RSpec
ENV['RAILS_ENV'] ||= 'test'
require File.expand_path('../../config/environment', __FILE__)
require 'rspec/rails'

Dir[Rails.root.join('spec/support/**/*.rb')].each { |f| require f }

# Double-check that the schema is current
ActiveRecord::Migration.maintain_test_schema!

RSpec.configure do |config|
  # Switch to the new RSpec syntax
  config.expect_with(:rspec) do |e|
    e.include_chain_clauses_in_custom_matcher_descriptions = true
  end
  config.mock_with(:rspec) do |m|
    m.verify_partial_doubles = true
  end

  config.disable_monkey_patching!
  config.color = true
  config.tty = true
  config.order = :random

  # We're going to use database_cleaner, so we don't need RSpec's transactional
  # fixture support
  config.use_transactional_fixtures = false

  config.before(:suite) do
    # Prepare the database
    DatabaseCleaner.clean_with(:truncation)

    # Use transactions to clean database
    DatabaseCleaner.strategy = :transaction
  end

  config.around(:example) do |example|
    # Reset the locale and timezone to defaults on each new test
    I18n.locale = I18n.default_locale
    Time.zone = 'Eastern Time (US & Canada)'

    # I'm not sure why this has stopped being called, but call it manually
    if example.metadata[:type].in?([:controller, :mailer, :decorator])
      Draper::ViewContext.clear!
    end

    DatabaseCleaner.cleaning do
      example.run
    end
  end

  # Add a variety of test helpers
  config.include Devise::TestHelpers, type: :controller
  config.include FactoryGirl::Syntax::Methods
  config.include SearchControllerQuery, type: :view
  config.include ParseJson, type: :request
  config.include StubConnection
end

FactoryGirl::SyntaxRunner.include(RSpec::Mocks::ExampleMethods)
