# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Avo::Workflows::Base do
  # Test workflow class
  let(:test_workflow_class) do
    Class.new(described_class) do
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

  describe '.step' do
    it 'defines a workflow step' do
      expect(test_workflow_class.step_names).to include(:draft, :review, :approved, :rejected)
    end

    it 'returns a StepDefinition object' do
      step_def = test_workflow_class.find_step(:draft)
      expect(step_def).to be_a(Avo::Workflows::Base::StepDefinition)
      expect(step_def.name).to eq(:draft)
    end
  end

  describe '.step_names' do
    it 'returns all defined step names' do
      expect(test_workflow_class.step_names).to eq([:draft, :review, :approved, :rejected])
    end
  end

  describe '.find_step' do
    it 'finds step by name' do
      step = test_workflow_class.find_step(:draft)
      expect(step.name).to eq(:draft)
    end

    it 'returns nil for non-existent step' do
      expect(test_workflow_class.find_step(:nonexistent)).to be_nil
    end
  end

  describe '.final_steps' do
    it 'identifies steps with no actions as final' do
      expect(test_workflow_class.final_steps).to eq([:approved])
    end
  end

  describe '.initial_step' do
    it 'returns the first defined step' do
      expect(test_workflow_class.initial_step).to eq(:draft)
    end
  end

  describe '#available_actions_for_step' do
    subject { test_workflow_class.new }

    it 'returns available actions for a step' do
      actions = subject.available_actions_for_step(:draft)
      expect(actions).to include(:submit, :save)
    end

    it 'returns empty array for non-existent step' do
      actions = subject.available_actions_for_step(:nonexistent)
      expect(actions).to eq([])
    end
  end

  describe '#can_transition?' do
    subject { test_workflow_class.new }

    it 'returns true for valid transitions' do
      expect(subject.can_transition?(:draft, :submit, :review)).to be true
    end

    it 'returns false for invalid transitions' do
      expect(subject.can_transition?(:draft, :submit, :approved)).to be false
    end
  end

  describe '#final_step?' do
    subject { test_workflow_class.new }

    it 'returns true for final steps' do
      expect(subject.final_step?(:approved)).to be true
    end

    it 'returns false for non-final steps' do
      expect(subject.final_step?(:draft)).to be false
    end
  end

  describe 'StepDefinition' do
    let(:step_def) { Avo::Workflows::Base::StepDefinition.new(:test_step) }

    describe '#action' do
      it 'defines an action with target step' do
        step_def.action(:proceed, to: :next_step)
        expect(step_def.actions[:proceed]).to eq({ to: :next_step, condition: nil })
      end

      it 'stores condition for action' do
        condition = proc { |context| context[:valid] }
        step_def.action(:conditional_action, to: :next_step, condition: condition)
        expect(step_def.actions[:conditional_action][:condition]).to eq(condition)
      end
    end

    describe '#condition' do
      it 'stores conditions for the step' do
        condition = proc { true }
        step_def.condition(&condition)
        expect(step_def.conditions).to include(condition)
      end
    end
  end
end