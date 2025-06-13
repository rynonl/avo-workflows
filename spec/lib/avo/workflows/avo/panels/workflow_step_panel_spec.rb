# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Avo::Workflows::Avo::Panels::WorkflowStepPanel', type: :model do
  before(:all) do
    load File.expand_path('../../../../../../lib/avo/workflows/avo/panels/workflow_step_panel.rb', __dir__)
  end

  let(:user) { User.create!(name: 'Test User', email: 'test@example.com') }
  let(:document) { Post.create!(title: 'Test Document', content: 'Test content', user: user) }
  let(:workflow_execution) do
    Avo::Workflows::WorkflowExecution.create!(
      workflow_class: 'DocumentApprovalWorkflow',
      workflowable: document,
      current_step: 'draft',
      assigned_to: user,
      context_data: { initial: true }
    )
  end
  let(:panel) { Avo::Workflows::Avo::Panels::WorkflowStepPanel.new(record: workflow_execution) }

  describe '#visible?' do
    it 'is visible for workflow executions with current step' do
      expect(panel.visible?).to be_truthy
    end

    it 'is not visible for non-workflow executions' do
      other_record = double('other_record')
      panel = described_class.new(record: other_record)
      expect(panel.visible?).to be_falsy
    end

    it 'is not visible for workflow executions without current step' do
      workflow_execution.update!(current_step: nil)
      expect(panel.visible?).to be_falsy
    end
  end

  describe '#title' do
    it 'returns humanized current step' do
      workflow_execution.update!(current_step: 'pending_review')
      expect(panel.title).to eq('Step: Pending review')
    end
  end

  describe '#body' do
    it 'returns HTML content when visible' do
      allow(panel).to receive(:visible?).and_return(true)
      allow(Avo::Workflows::Registry).to receive(:find).and_return(nil)
      
      body = panel.body
      expect(body).to eq("Workflow class not found")
    end

    it 'returns nil when not visible' do
      allow(panel).to receive(:visible?).and_return(false)
      
      expect(panel.body).to be_nil
    end
  end

  describe 'panel configuration' do
    it 'has correct name' do
      expect(Avo::Workflows::Avo::Panels::WorkflowStepPanel.name).to eq("Current Step Details")
    end

    it 'is not collapsible' do
      expect(Avo::Workflows::Avo::Panels::WorkflowStepPanel.collapsible).to be_falsy
    end
  end
end