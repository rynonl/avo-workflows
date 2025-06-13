# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Avo::Workflows::Validators do
  # Test workflow classes
  let(:valid_workflow_class) do
    Class.new(Avo::Workflows::Base) do
      def self.name
        "ValidWorkflow"
      end

      step :start do
        action :proceed, to: :middle
      end

      step :middle do
        action :finish, to: :end
        action :back, to: :start
      end

      step :end do
        # Final step
      end
    end
  end

  let(:invalid_workflow_class) do
    Class.new(Avo::Workflows::Base) do
      def self.name
        "InvalidWorkflow"
      end

      step :start do
        action :proceed, to: :nonexistent_step
      end
    end
  end

  let(:unreachable_workflow_class) do
    Class.new(Avo::Workflows::Base) do
      def self.name
        "UnreachableWorkflow"
      end

      step :start do
        action :proceed, to: :middle
      end

      step :middle do
        action :finish, to: :end
      end

      step :end do
        # Final step
      end

      step :unreachable do
        # This step cannot be reached
      end
    end
  end

  let(:empty_workflow_class) do
    Class.new(Avo::Workflows::Base) do
      def self.name
        "EmptyWorkflow"
      end
      # No steps defined
    end
  end

  describe '.validate_workflow_definition' do
    it 'returns no errors for valid workflow' do
      errors = described_class.validate_workflow_definition(valid_workflow_class)
      expect(errors).to be_empty
    end

    it 'returns error for workflow with no steps' do
      errors = described_class.validate_workflow_definition(empty_workflow_class)
      expect(errors).to include(/must define at least one step/)
    end

    it 'returns error for invalid action target' do
      errors = described_class.validate_workflow_definition(invalid_workflow_class)
      expect(errors).to include(/targets non-existent step/)
    end

    it 'returns error for unreachable steps' do
      errors = described_class.validate_workflow_definition(unreachable_workflow_class)
      expect(errors).to include(/Unreachable steps found: unreachable/)
    end
  end

  describe '.validate_step' do
    it 'returns no errors for valid step' do
      errors = described_class.validate_step(valid_workflow_class, :start)
      expect(errors).to be_empty
    end

    it 'returns error for step with invalid action target' do
      errors = described_class.validate_step(invalid_workflow_class, :start)
      expect(errors).to include(/targets non-existent step/)
    end

    it 'returns empty array for non-existent step' do
      errors = described_class.validate_step(valid_workflow_class, :nonexistent)
      expect(errors).to be_empty
    end
  end

  describe '.validate_execution' do
    let(:execution) { double('execution') }

    context 'with valid execution' do
      before do
        allow(execution).to receive(:workflow_class).and_return('ValidWorkflow')
        allow(execution).to receive(:current_step).and_return('start')
        allow(execution).to receive(:workflow_definition).and_return(valid_workflow_class.new)
      end

      it 'returns no errors' do
        errors = described_class.validate_execution(execution)
        expect(errors).to be_empty
      end
    end

    context 'with non-existent workflow class' do
      before do
        allow(execution).to receive(:workflow_class).and_return('NonExistentWorkflow')
        allow(execution).to receive(:workflow_definition).and_raise(NameError)
      end

      it 'returns workflow class error' do
        errors = described_class.validate_execution(execution)
        expect(errors).to include(/not found/)
      end
    end

    context 'with invalid current step' do
      before do
        allow(execution).to receive(:workflow_class).and_return('ValidWorkflow')
        allow(execution).to receive(:current_step).and_return('invalid_step')
        allow(execution).to receive(:workflow_definition).and_return(valid_workflow_class.new)
      end

      it 'returns current step error' do
        errors = described_class.validate_execution(execution)
        expect(errors).to include(/not defined in workflow/)
      end
    end
  end

  describe '.validate_transition' do
    let(:execution) { double('execution') }

    context 'with valid transition' do
      before do
        allow(execution).to receive(:available_actions).and_return([:proceed])
        allow(execution).to receive(:current_step).and_return('start')
        allow(execution).to receive(:context_data).and_return({})
        
        step_def = double('step_def')
        allow(step_def).to receive(:conditions).and_return([])
        
        workflow_def = double('workflow_def')
        allow(workflow_def).to receive(:class).and_return(valid_workflow_class)
        allow(valid_workflow_class).to receive(:find_step).and_return(step_def)
        
        allow(execution).to receive(:workflow_definition).and_return(workflow_def)
      end

      it 'returns no errors' do
        errors = described_class.validate_transition(execution, :proceed)
        expect(errors).to be_empty
      end
    end

    context 'with invalid action' do
      before do
        allow(execution).to receive(:available_actions).and_return([])
        allow(execution).to receive(:current_step).and_return('start')
        allow(execution).to receive(:context_data).and_return({})
        
        step_def = double('step_def')
        allow(step_def).to receive(:conditions).and_return([])
        
        workflow_def = double('workflow_def')
        allow(workflow_def).to receive(:class).and_return(valid_workflow_class)
        allow(valid_workflow_class).to receive(:find_step).and_return(step_def)
        
        allow(execution).to receive(:workflow_definition).and_return(workflow_def)
      end

      it 'returns action not available error' do
        errors = described_class.validate_transition(execution, :invalid_action)
        expect(errors).to include(/not available/)
      end
    end

    context 'with unsatisfied step conditions' do
      before do
        allow(execution).to receive(:available_actions).and_return([:proceed])
        allow(execution).to receive(:current_step).and_return('start')
        allow(execution).to receive(:context_data).and_return({})
        
        failing_condition = proc { |context| false }
        step_def = double('step_def')
        allow(step_def).to receive(:conditions).and_return([failing_condition])
        allow(step_def).to receive(:satisfies_conditions?).and_return(false)
        
        workflow_def = double('workflow_def')
        allow(workflow_def).to receive(:class).and_return(valid_workflow_class)
        allow(valid_workflow_class).to receive(:find_step).and_return(step_def)
        
        allow(execution).to receive(:workflow_definition).and_return(workflow_def)
      end

      it 'returns step conditions error' do
        errors = described_class.validate_transition(execution, :proceed)
        expect(errors).to include(/conditions not satisfied/)
      end
    end
  end
end