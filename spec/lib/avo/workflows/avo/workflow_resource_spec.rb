# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Avo::Workflows::Avo::WorkflowResource', type: :model do
  before(:all) do
    # Force reload the Avo integration components now that mocks are available
    require_relative '../../../../../../lib/avo/workflows/avo/workflow_resource'
    require_relative '../../../../../../lib/avo/workflows/avo/filters/workflow_class_filter'
    require_relative '../../../../../../lib/avo/workflows/avo/filters/status_filter'
    require_relative '../../../../../../lib/avo/workflows/avo/filters/current_step_filter'
    require_relative '../../../../../../lib/avo/workflows/avo/actions/perform_workflow_action'
    require_relative '../../../../../../lib/avo/workflows/avo/actions/assign_workflow'
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
  let(:resource) { Avo::Workflows::Avo::WorkflowResource.new }

  before do
    # Allow resource to access the model
    allow(resource).to receive(:model).and_return(workflow_execution)
  end

  describe 'class configuration' do
    it 'extends Avo::BaseResource' do
      expect(Avo::Workflows::Avo::WorkflowResource.superclass).to eq(Avo::BaseResource)
    end

    it 'has correct model class' do
      expect(Avo::Workflows::Avo::WorkflowResource.model_class).to eq(Avo::Workflows::WorkflowExecution)
    end

    it 'includes necessary associations' do
      expect(Avo::Workflows::Avo::WorkflowResource.includes).to include(:workflowable, :assigned_to)
    end
  end

  describe 'resource methods' do
    it 'responds to fields method' do
      expect(resource).to respond_to(:fields)
    end

    it 'responds to filters method' do
      expect(resource).to respond_to(:filters)
    end

    it 'responds to actions method' do
      expect(resource).to respond_to(:actions)
    end

    it 'responds to panels method' do
      expect(resource).to respond_to(:panels)
    end
  end

  describe 'private methods' do
    describe '#step_color' do
      it 'returns green for final steps' do
        workflow_def = double('workflow_def')
        allow(workflow_def).to receive(:final_step?).with(:approved).and_return(true)
        
        color = resource.send(:step_color, :approved, workflow_def)
        expect(color).to eq(:green)
      end

      it 'returns yellow for pending/review steps' do
        workflow_def = double('workflow_def')
        allow(workflow_def).to receive(:final_step?).and_return(false)
        
        color = resource.send(:step_color, :pending_review, workflow_def)
        expect(color).to eq(:yellow)
      end

      it 'returns blue for draft/new steps' do
        workflow_def = double('workflow_def')
        allow(workflow_def).to receive(:final_step?).and_return(false)
        
        color = resource.send(:step_color, :draft, workflow_def)
        expect(color).to eq(:blue)
      end

      it 'returns red for rejected/failed steps' do
        workflow_def = double('workflow_def')
        allow(workflow_def).to receive(:final_step?).and_return(false)
        
        color = resource.send(:step_color, :rejected, workflow_def)
        expect(color).to eq(:red)
      end

      it 'returns gray for other steps' do
        workflow_def = double('workflow_def')
        allow(workflow_def).to receive(:final_step?).and_return(false)
        
        color = resource.send(:step_color, :other_step, workflow_def)
        expect(color).to eq(:gray)
      end
    end

    describe '#status_color' do
      it 'returns correct colors for each status' do
        expect(resource.send(:status_color, 'active')).to eq(:blue)
        expect(resource.send(:status_color, 'completed')).to eq(:green)
        expect(resource.send(:status_color, 'failed')).to eq(:red)
        expect(resource.send(:status_color, 'paused')).to eq(:yellow)
        expect(resource.send(:status_color, 'unknown')).to eq(:gray)
      end
    end
  end
end