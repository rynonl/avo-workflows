# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Avo::Workflows::Error do
  let(:workflow_execution) { 
    double('WorkflowExecution', id: 123, current_step: 'test_step', workflow_class: 'TestWorkflow') 
  }
  let(:context) { { key: 'value' } }
  let(:details) { { detail: 'info' } }

  describe '#initialize' do
    it 'accepts message, workflow_execution, context, and details' do
      error = described_class.new(
        'Test error',
        workflow_execution: workflow_execution,
        context: context,
        details: details
      )

      expect(error.message).to eq('Test error')
      expect(error.workflow_execution).to eq(workflow_execution)
      expect(error.context).to eq(context)
      expect(error.details).to eq(details)
    end

    it 'works with just a message' do
      error = described_class.new('Simple error')
      
      expect(error.message).to eq('Simple error')
      expect(error.workflow_execution).to be_nil
      expect(error.context).to eq({})
      expect(error.details).to eq({})
    end
  end

  describe '#to_h' do
    let(:error) do
      described_class.new(
        'Test error',
        workflow_execution: workflow_execution,
        context: context,
        details: details
      )
    end

    it 'returns a hash representation of the error' do
      result = error.to_h

      expect(result).to include(
        error_class: 'Avo::Workflows::Error',
        message: 'Test error',
        workflow_execution_id: 123,
        current_step: 'test_step',
        context: context,
        details: details
      )
      expect(result[:backtrace]).to be_an(Array).or be_nil
      expect(result[:timestamp]).to be_present
    end

    it 'handles nil workflow_execution gracefully' do
      error = described_class.new('Test error')
      result = error.to_h

      expect(result[:workflow_execution_id]).to be_nil
      expect(result[:current_step]).to be_nil
      expect(result[:workflow_class]).to be_nil
    end

    it 'serializes complex context objects safely' do
      complex_context = {
        time: Time.current,
        symbol: :test,
        nested: { array: [1, 2, 3] }
      }
      error = described_class.new('Test error', context: complex_context)
      result = error.to_h

      expect(result[:context][:time]).to be_a(String)
      expect(result[:context][:symbol]).to eq('test')
      expect(result[:context][:nested][:array]).to eq(['1', '2', '3'])
    end
  end

  describe '#to_json' do
    it 'converts error to JSON string' do
      error = described_class.new('Test error')
      json_result = error.to_json

      expect { JSON.parse(json_result) }.not_to raise_error
      parsed = JSON.parse(json_result)
      expect(parsed['error_class']).to eq('Avo::Workflows::Error')
      expect(parsed['message']).to eq('Test error')
    end
  end

  describe '#belongs_to?' do
    let(:error) do
      described_class.new('Test error', workflow_execution: workflow_execution)
    end
    let(:other_execution) { double('OtherExecution', id: 456) }

    it 'returns true for matching workflow execution' do
      expect(error.belongs_to?(workflow_execution)).to be true
    end

    it 'returns false for different workflow execution' do
      expect(error.belongs_to?(other_execution)).to be false
    end

    it 'returns false when no workflow execution associated' do
      error = described_class.new('Test error')
      expect(error.belongs_to?(workflow_execution)).to be false
    end
  end

  describe '#retryable?' do
    it 'returns true for base error' do
      error = described_class.new('Test error')
      expect(error.retryable?).to be true
    end

    it 'returns false for workflow definition errors' do
      error = Avo::Workflows::WorkflowDefinitionError.new('Definition error')
      expect(error.retryable?).to be false
    end

    it 'returns false for permission errors' do
      error = Avo::Workflows::PermissionError.new('Permission error')
      expect(error.retryable?).to be false
    end

    it 'returns true for execution errors' do
      error = Avo::Workflows::WorkflowExecutionError.new('Execution error')
      expect(error.retryable?).to be true
    end
  end

  describe '#severity' do
    it 'returns :critical for workflow definition errors' do
      error = Avo::Workflows::WorkflowDefinitionError.new('Definition error')
      expect(error.severity).to eq(:critical)
    end

    it 'returns :critical for state corruption errors' do
      error = Avo::Workflows::StateCorruptionError.new('State corruption')
      expect(error.severity).to eq(:critical)
    end

    it 'returns :high for transition errors' do
      error = Avo::Workflows::TransitionError.new('Transition error')
      expect(error.severity).to eq(:high)
    end

    it 'returns :high for context errors' do
      error = Avo::Workflows::ContextError.new('Context error')
      expect(error.severity).to eq(:high)
    end

    it 'returns :medium for execution errors' do
      error = Avo::Workflows::WorkflowExecutionError.new('Execution error')
      expect(error.severity).to eq(:medium)
    end

    it 'returns :low for base errors' do
      error = described_class.new('Base error')
      expect(error.severity).to eq(:low)
    end
  end
end

RSpec.describe Avo::Workflows::WorkflowDefinitionError do
  it 'inherits from Error' do
    expect(described_class).to be < Avo::Workflows::Error
  end
end

RSpec.describe Avo::Workflows::InvalidStepError do
  it 'inherits from WorkflowDefinitionError' do
    expect(described_class).to be < Avo::Workflows::WorkflowDefinitionError
  end
end

RSpec.describe Avo::Workflows::InvalidActionError do
  it 'inherits from WorkflowDefinitionError' do
    expect(described_class).to be < Avo::Workflows::WorkflowDefinitionError
  end
end

RSpec.describe Avo::Workflows::WorkflowExecutionError do
  it 'inherits from Error' do
    expect(described_class).to be < Avo::Workflows::Error
  end
end

RSpec.describe Avo::Workflows::TransitionError do
  it 'inherits from WorkflowExecutionError' do
    expect(described_class).to be < Avo::Workflows::WorkflowExecutionError
  end
end

RSpec.describe Avo::Workflows::ConditionNotMetError do
  it 'inherits from TransitionError' do
    expect(described_class).to be < Avo::Workflows::TransitionError
  end
end

RSpec.describe Avo::Workflows::ContextError do
  it 'inherits from Error' do
    expect(described_class).to be < Avo::Workflows::Error
  end
end

RSpec.describe Avo::Workflows::PermissionError do
  it 'inherits from Error' do
    expect(described_class).to be < Avo::Workflows::Error
  end
end

RSpec.describe Avo::Workflows::RecoveryError do
  it 'inherits from Error' do
    expect(described_class).to be < Avo::Workflows::Error
  end
end