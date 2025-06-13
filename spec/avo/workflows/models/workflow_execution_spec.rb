# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Avo::Workflows::WorkflowExecution do
  # Test workflow class
  let(:test_workflow_class) do
    Class.new(Avo::Workflows::Base) do
      step :draft do
        action :submit, to: :review
        action :save, to: :draft
      end

      step :review do
        action :approve, to: :approved
        action :reject, to: :rejected
        action :request_changes, to: :draft
      end

      step :approved do
        # Final step
      end

      step :rejected do
        action :resubmit, to: :draft
      end
    end
  end

  let(:post) { Post.create!(title: 'Test Post', content: 'Test content', user: user) }
  let(:user) { User.create!(name: 'Test User', email: 'test@example.com') }
  
  let(:workflow_execution) do
    described_class.create!(
      workflow_class: 'TestWorkflow',
      workflowable: post,
      current_step: 'draft',
      context_data: { initial: true }
    )
  end

  before do
    stub_const('TestWorkflow', test_workflow_class)
  end

  describe 'validations' do
    it 'requires workflow_class' do
      execution = described_class.new(workflowable: post, current_step: 'draft')
      expect(execution).not_to be_valid
      expect(execution.errors[:workflow_class]).to include("can't be blank")
    end

    it 'requires current_step' do
      execution = described_class.new(workflow_class: 'TestWorkflow', workflowable: post)
      expect(execution).not_to be_valid
      expect(execution.errors[:current_step]).to include("can't be blank")
    end

    it 'validates status inclusion' do
      execution = described_class.new(
        workflow_class: 'TestWorkflow',
        workflowable: post,
        current_step: 'draft',
        status: 'invalid'
      )
      expect(execution).not_to be_valid
      expect(execution.errors[:status]).to include('is not included in the list')
    end
  end

  describe 'associations' do
    it 'belongs to workflowable' do
      expect(workflow_execution.workflowable).to eq(post)
    end

    it 'can belong to assigned_to user' do
      workflow_execution.update!(assigned_to: user)
      expect(workflow_execution.assigned_to).to eq(user)
    end
  end

  describe 'scopes' do
    before do
      # Ensure the main workflow_execution exists
      workflow_execution
      
      described_class.create!(
        workflow_class: 'TestWorkflow',
        workflowable: post,
        current_step: 'approved',
        status: 'completed'
      )
      
      described_class.create!(
        workflow_class: 'TestWorkflow',
        workflowable: post,
        current_step: 'draft',
        status: 'failed'
      )
    end

    it 'filters by status' do
      expect(described_class.active.count).to eq(1)
      expect(described_class.completed.count).to eq(1)
      expect(described_class.failed.count).to eq(1)
    end

    it 'filters by workflow class' do
      expect(described_class.for_workflow('TestWorkflow').count).to eq(3)
      expect(described_class.for_workflow('OtherWorkflow').count).to eq(0)
    end
  end

  describe '#workflow_definition' do
    it 'returns an instance of the workflow class' do
      expect(workflow_execution.workflow_definition).to be_a(test_workflow_class)
    end
  end

  describe '#available_actions' do
    it 'returns available actions for current step' do
      expect(workflow_execution.available_actions).to include(:submit, :save)
    end

    context 'when in review step' do
      before { workflow_execution.update!(current_step: 'review') }

      it 'returns review actions' do
        expect(workflow_execution.available_actions).to include(:approve, :reject, :request_changes)
      end
    end
  end

  describe '#can_transition_to?' do
    it 'returns true for valid transitions' do
      expect(workflow_execution.can_transition_to?(:review)).to be true
    end

    it 'returns false for invalid transitions' do
      expect(workflow_execution.can_transition_to?(:approved)).to be false
    end
  end

  describe '#perform_action' do
    it 'transitions to the correct step' do
      expect(workflow_execution.perform_action(:submit, user: user)).to be true
      expect(workflow_execution.reload.current_step).to eq('review')
    end

    it 'updates context data' do
      additional_context = { submitted_by: user.id }
      workflow_execution.perform_action(:submit, user: user, additional_context: additional_context)
      
      expect(workflow_execution.reload.context_data).to include(
        'initial' => true,
        'submitted_by' => user.id
      )
    end

    it 'assigns the user' do
      workflow_execution.perform_action(:submit, user: user)
      expect(workflow_execution.reload.assigned_to).to eq(user)
    end

    it 'records transition history' do
      workflow_execution.perform_action(:submit, user: user)
      
      history = workflow_execution.reload.history
      expect(history.last).to include(
        'from_step' => 'draft',
        'to_step' => 'review',
        'action' => 'submit',
        'user_id' => user.id,
        'user_type' => 'User'
      )
    end

    it 'marks as completed when reaching final step' do
      workflow_execution.update!(current_step: 'review')
      workflow_execution.perform_action(:approve, user: user)
      
      expect(workflow_execution.reload.status).to eq('completed')
    end

    it 'returns false for invalid actions' do
      expect(workflow_execution.perform_action(:invalid_action, user: user)).to be false
    end

    it 'marks as failed on exception' do
      # Mock the workflow_execution to raise an error during update, but allow the status update to work
      allow(workflow_execution).to receive(:update!).and_call_original
      allow(workflow_execution).to receive(:update!).with(hash_including(:current_step)).and_raise(StandardError.new('Test error'))
      
      expect { workflow_execution.perform_action(:submit, user: user) }.to raise_error(StandardError)
      expect(workflow_execution.reload.status).to eq('failed')
    end
  end

  describe '#context_value and #set_context_value' do
    it 'gets and sets context values' do
      workflow_execution.set_context_value(:test_key, 'test_value')
      expect(workflow_execution.context_value(:test_key)).to eq('test_value')
    end
  end

  describe '#history' do
    it 'returns empty array when no history' do
      execution = described_class.new
      expect(execution.history).to eq([])
    end

    it 'returns step history' do
      workflow_execution.perform_action(:submit, user: user)
      expect(workflow_execution.history).not_to be_empty
    end
  end

  describe 'defaults' do
    it 'sets default values on initialization' do
      execution = described_class.new
      expect(execution.context_data).to eq({})
      expect(execution.step_history).to eq([])
      expect(execution.status).to eq('active')
    end
  end
end