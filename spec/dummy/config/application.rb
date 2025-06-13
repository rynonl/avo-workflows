# frozen_string_literal: true

require 'rails/all'

Bundler.require(*Rails.groups)
require "avo/workflows"

module Dummy
  class Application < Rails::Application
    config.load_defaults Rails::VERSION::STRING.to_f

    # For compatibility with applications that use this config
    config.action_controller.include_all_helpers = false

    # Configuration for the application, engines, and railties goes here.
    config.eager_load = false
    
    # Don't generate system test files.
    config.generators.system_tests = nil
    
    # Use SQL instead of Active Record's schema dumper when creating the database.
    config.active_record.schema_format = :ruby

    # Configure database inline for testing
    config.after_initialize do
      ActiveRecord::Base.establish_connection(
        adapter: 'sqlite3',
        database: ':memory:'
      )
    end
  end
end