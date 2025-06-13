# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Avo::Workflows::Registry do
  # Test workflow classes
  let(:test_workflow_class_1) do
    Class.new(Avo::Workflows::Base) do
      def self.name
        "TestWorkflow1"
      end

      step :start do
        action :proceed, to: :finish
      end

      step :finish
    end
  end

  let(:test_workflow_class_2) do
    Class.new(Avo::Workflows::Base) do
      def self.name
        "TestWorkflow2"
      end

      step :draft do
        action :submit, to: :review
      end

      step :review
    end
  end

  before do
    described_class.clear!
  end

  describe '.register' do
    it 'registers a workflow class' do
      described_class.register(test_workflow_class_1)
      expect(described_class.workflows['TestWorkflow1']).to eq(test_workflow_class_1)
    end

    it 'can register multiple workflows' do
      described_class.register(test_workflow_class_1)
      described_class.register(test_workflow_class_2)
      
      expect(described_class.workflows.keys).to include('TestWorkflow1', 'TestWorkflow2')
    end
  end

  describe '.find' do
    before do
      described_class.register(test_workflow_class_1)
    end

    it 'finds a registered workflow by name' do
      expect(described_class.find('TestWorkflow1')).to eq(test_workflow_class_1)
    end

    it 'finds a workflow by symbol name' do
      expect(described_class.find(:TestWorkflow1)).to eq(test_workflow_class_1)
    end

    it 'returns nil for non-existent workflow' do
      expect(described_class.find('NonExistentWorkflow')).to be_nil
    end
  end

  describe '.all' do
    before do
      described_class.clear!
      described_class.register(test_workflow_class_1)
      described_class.register(test_workflow_class_2)
    end

    it 'returns all registered workflows' do
      workflows = described_class.all
      expect(workflows).to include(test_workflow_class_1, test_workflow_class_2)
      expect(workflows.length).to be >= 2
    end
  end

  describe '.workflow_names' do
    before do
      described_class.clear!
      described_class.register(test_workflow_class_1)
      described_class.register(test_workflow_class_2)
    end

    it 'returns all workflow names' do
      names = described_class.workflow_names
      expect(names).to include('TestWorkflow1', 'TestWorkflow2')
      expect(names.length).to be >= 2
    end
  end

  describe '.clear!' do
    before do
      described_class.register(test_workflow_class_1)
    end

    it 'clears all registered workflows' do
      expect(described_class.workflows).not_to be_empty
      described_class.clear!
      expect(described_class.workflows).to be_empty
    end
  end

  describe '.workflow_exists?' do
    before do
      described_class.register(test_workflow_class_1)
    end

    it 'returns true for existing workflow' do
      expect(described_class.workflow_exists?('TestWorkflow1')).to be true
    end

    it 'returns false for non-existing workflow' do
      expect(described_class.workflow_exists?('NonExistentWorkflow')).to be false
    end
  end

  describe '.create_execution' do
    let(:workflowable) { double('workflowable') }
    
    before do
      described_class.register(test_workflow_class_1)
      allow(test_workflow_class_1).to receive(:create_execution_for).and_return(double('execution'))
    end

    it 'creates execution for registered workflow' do
      expect(test_workflow_class_1).to receive(:create_execution_for)
        .with(workflowable, assigned_to: nil)
        
      described_class.create_execution('TestWorkflow1', workflowable, assigned_to: nil)
    end

    it 'raises error for non-existent workflow' do
      expect {
        described_class.create_execution('NonExistentWorkflow', workflowable)
      }.to raise_error(Avo::Workflows::Error, /Workflow 'NonExistentWorkflow' not found/)
    end
  end

  describe '.register via inheritance' do
    it 'can register workflow classes manually' do
      # Create a new workflow class that inherits from Base
      # Define it as a constant so it has a proper name
      workflow_class = Class.new(Avo::Workflows::Base)
      Object.const_set('ManuallyRegisteredWorkflow', workflow_class)

      # Register manually
      described_class.register(ManuallyRegisteredWorkflow)

      # Should be registered
      expect(described_class.workflow_exists?('ManuallyRegisteredWorkflow')).to be true
      expect(described_class.find('ManuallyRegisteredWorkflow')).to eq(ManuallyRegisteredWorkflow)
      
      # Clean up the constant
      Object.send(:remove_const, 'ManuallyRegisteredWorkflow') if Object.const_defined?('ManuallyRegisteredWorkflow')
    end
  end
end