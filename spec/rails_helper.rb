# frozen_string_literal: true

require 'spec_helper'
require 'avo/workflows'

# Dummy Rails app for testing
require 'rails'
require 'active_record'
require 'action_controller/railtie'

module Dummy
  class Application < Rails::Application
    config.eager_load = false
    config.active_support.deprecation = :log
    config.logger = Logger.new($stdout)
    config.log_level = :fatal
  end
end

# Configure test database
ActiveRecord::Base.establish_connection(
  adapter: 'sqlite3',
  database: ':memory:'
)

# Load ActiveRecord schema
ActiveRecord::Schema.define(version: 1) do
  create_table :avo_workflow_executions do |t|
    t.string :workflow_class, null: false
    t.references :workflowable, polymorphic: true, null: false
    t.string :current_step, null: false
    t.json :context_data
    t.json :step_history
    t.string :status, default: 'active'
    t.references :assigned_to, polymorphic: true, null: true
    t.timestamps
  end

  # Test models
  create_table :users do |t|
    t.string :name
    t.string :email
    t.timestamps
  end

  create_table :posts do |t|
    t.string :title
    t.string :content
    t.string :status, default: 'draft'
    t.references :user, foreign_key: true
    t.timestamps
  end
end

# Test models
class User < ActiveRecord::Base
  has_many :posts
end

class Post < ActiveRecord::Base
  belongs_to :user
end

Dummy::Application.initialize!

RSpec.configure do |config|
  config.before(:suite) do
    ActiveRecord::Migration.maintain_test_schema!
  end

  config.around(:each) do |example|
    ActiveRecord::Base.transaction do
      example.run
      raise ActiveRecord::Rollback
    end
  end
end