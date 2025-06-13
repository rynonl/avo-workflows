# frozen_string_literal: true

require 'spec_helper'
require 'support/avo_mocks'
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

  # Blog posts table for examples
  create_table :blog_posts do |t|
    t.string :title, null: false, limit: 200
    t.text :content, null: false
    t.text :excerpt, limit: 500
    t.string :tags, limit: 100
    t.references :author, null: false, foreign_key: { to_table: :users }
    t.references :editor, null: true, foreign_key: { to_table: :users }
    t.string :slug, limit: 250
    t.string :meta_description, limit: 160
    t.string :featured_image_url
    t.datetime :published_at
    t.boolean :featured, default: false
    t.integer :view_count, default: 0
    t.timestamps
  end

  # Employees table for advanced workflow examples
  create_table :employees do |t|
    t.string :name, null: false, limit: 100
    t.string :email, null: false, limit: 150
    t.string :employee_id, limit: 20
    t.string :phone, limit: 20
    t.string :employee_type, null: false, limit: 20
    t.string :department, null: false, limit: 50
    t.string :job_title, limit: 100
    t.string :salary_level, null: false, limit: 20
    t.date :start_date, null: false
    t.date :end_date
    t.string :security_clearance, limit: 20
    t.text :special_requirements
    t.references :manager, null: true, foreign_key: { to_table: :users }
    t.references :mentor, null: true, foreign_key: { to_table: :users }
    t.references :hr_representative, null: true, foreign_key: { to_table: :users }
    t.text :address
    t.string :emergency_contact_name, limit: 100
    t.string :emergency_contact_phone, limit: 20
    t.string :status, default: 'pending_onboarding', limit: 30
    t.text :notes
    t.json :additional_data
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

# Define ApplicationRecord for Rails 5+ compatibility
class ApplicationRecord < ActiveRecord::Base
  self.abstract_class = true
end

# Load example classes
require_relative '../examples/models/blog_post'
require_relative '../examples/workflows/blog_post_workflow'
require_relative '../examples/models/employee'
require_relative '../examples/workflows/employee_onboarding_workflow'

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