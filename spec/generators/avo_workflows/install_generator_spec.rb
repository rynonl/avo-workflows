# frozen_string_literal: true

require 'rails_helper'

class InstallGeneratorTest < Rails::Generators::TestCase
  tests AvoWorkflows::Generators::InstallGenerator
  destination File.expand_path("../../../tmp/generator_test", __dir__)

  setup do
    prepare_destination
  end

  def test_creates_migration_file
    run_generator

    migration_file = find_migration_file('create_avo_workflow_executions')
    assert migration_file, "Migration file should be created"
    
    content = File.read(migration_file)
    assert_match(/create_table :avo_workflow_executions/, content)
    assert_match(/t\.string :workflow_class, null: false/, content)
    assert_match(/t\.references :workflowable, polymorphic: true/, content)
  end

  def test_creates_initializer
    run_generator

    assert_file "config/initializers/avo_workflows.rb" do |content|
      assert_match(/Avo::Workflows\.configure/, content)
    end
  end

  def test_creates_workflows_directory
    run_generator

    assert_file "app/avo/workflows/.keep"
  end

  def test_creates_example_workflow
    run_generator

    assert_file "app/avo/workflows/example_workflow.rb" do |content|
      assert_match(/class ExampleWorkflow < Avo::Workflows::Base/, content)
      assert_match(/step :draft/, content)
    end
  end

  private

  def find_migration_file(name)
    Dir.glob("#{destination_root}/db/migrate/*_#{name}.rb").first
  end
end

# RSpec wrapper for the TestCase
RSpec.describe AvoWorkflows::Generators::InstallGenerator, type: :generator do
  let(:test_case) { InstallGeneratorTest.new }

  before do
    test_case.setup
  end

  it 'creates migration file' do
    test_case.test_creates_migration_file
  end

  it 'creates initializer' do
    test_case.test_creates_initializer
  end

  it 'creates workflows directory' do
    test_case.test_creates_workflows_directory
  end

  it 'creates example workflow' do
    test_case.test_creates_example_workflow
  end
end