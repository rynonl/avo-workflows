# frozen_string_literal: true

require 'rails_helper'

class WorkflowGeneratorTest < Rails::Generators::TestCase
  tests AvoWorkflows::Generators::WorkflowGenerator
  destination File.expand_path("../../../tmp/generator_test", __dir__)

  setup do
    prepare_destination
  end

  def test_creates_workflow_with_default_steps
    run_generator %w[approval]

    assert_file "app/avo/workflows/approval_workflow.rb" do |content|
      assert_match(/class ApprovalWorkflow < Avo::Workflows::Base/, content)
      assert_match(/step :draft/, content)
      assert_match(/step :pending_review/, content)
      assert_match(/step :approved/, content)
    end
  end

  def test_creates_workflow_with_custom_steps
    run_generator %w[order submitted processing completed]

    assert_file "app/avo/workflows/order_workflow.rb" do |content|
      assert_match(/class OrderWorkflow < Avo::Workflows::Base/, content)
      assert_match(/step :submitted/, content)
      assert_match(/step :processing/, content)
      assert_match(/step :completed/, content)
    end
  end

  def test_creates_workflow_spec
    run_generator %w[approval]

    assert_file "spec/avo/workflows/approval_workflow_spec.rb" do |content|
      assert_match(/RSpec\.describe ApprovalWorkflow/, content)
    end
  end
end

# RSpec wrapper for the TestCase
RSpec.describe AvoWorkflows::Generators::WorkflowGenerator, type: :generator do
  let(:test_case) { WorkflowGeneratorTest.new }

  before do
    test_case.setup
  end

  it 'creates workflow file with default steps' do
    test_case.test_creates_workflow_with_default_steps
  end

  it 'creates workflow file with custom steps' do
    test_case.test_creates_workflow_with_custom_steps
  end

  it 'creates workflow spec file' do
    test_case.test_creates_workflow_spec
  end
end