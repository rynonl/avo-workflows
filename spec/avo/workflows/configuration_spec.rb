# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Avo::Workflows::Configuration do
  subject(:config) { described_class.new }

  describe '#initialize' do
    it 'sets default values' do
      expect(config.user_class).to eq('User')
      expect(config.workflow_execution_class).to eq('Avo::Workflows::WorkflowExecution')
      expect(config.enabled).to be true
    end
  end

  describe '#user_class=' do
    it 'accepts valid class names' do
      config.user_class = 'Admin::User'
      expect(config.user_class).to eq('Admin::User')
    end

    it 'accepts nil' do
      config.user_class = nil
      expect(config.user_class).to be_nil
    end

    it 'raises error for invalid class names' do
      expect { config.user_class = 'invalid_class' }.to raise_error(ArgumentError, /must be a valid Ruby class name/)
      expect { config.user_class = '' }.to raise_error(ArgumentError, /must be a non-empty string/)
      expect { config.user_class = 123 }.to raise_error(ArgumentError, /must be a non-empty string/)
    end
  end

  describe '#workflow_execution_class=' do
    it 'accepts valid class names' do
      config.workflow_execution_class = 'CustomWorkflowExecution'
      expect(config.workflow_execution_class).to eq('CustomWorkflowExecution')
    end

    it 'raises error for invalid class names' do
      expect { config.workflow_execution_class = 'invalid_class' }.to raise_error(ArgumentError, /must be a valid Ruby class name/)
      expect { config.workflow_execution_class = '' }.to raise_error(ArgumentError, /must be a non-empty string/)
      expect { config.workflow_execution_class = nil }.to raise_error(ArgumentError, /must be a non-empty string/)
    end
  end

  describe '#enabled=' do
    it 'converts truthy values to true' do
      config.enabled = 'yes'
      expect(config.enabled).to be true

      config.enabled = 1
      expect(config.enabled).to be true
    end

    it 'converts falsy values to false' do
      config.enabled = nil
      expect(config.enabled).to be false

      config.enabled = false
      expect(config.enabled).to be false
    end

    it 'converts truthy values to true including zero and empty string' do
      config.enabled = 0
      expect(config.enabled).to be true

      config.enabled = ''
      expect(config.enabled).to be true
    end
  end

  describe '#user_model' do
    context 'when user_class exists' do
      before do
        config.user_class = 'User'
        stub_const('User', Class.new)
      end

      it 'returns the constantized class' do
        expect(config.user_model).to eq(User)
      end
    end

    context 'when user_class does not exist' do
      before { config.user_class = 'NonExistentUser' }

      it 'raises an error' do
        expect { config.user_model }.to raise_error(
          Avo::Workflows::Error,
          /User class 'NonExistentUser' not found/
        )
      end
    end

    context 'when user_class is nil' do
      before { config.user_class = nil }

      it 'returns nil' do
        expect(config.user_model).to be_nil
      end
    end
  end

  describe '#workflow_execution_model' do
    context 'when workflow_execution_class exists' do
      before do
        config.workflow_execution_class = 'TestWorkflowExecution'
        stub_const('TestWorkflowExecution', Class.new)
      end

      it 'returns the constantized class' do
        expect(config.workflow_execution_model).to eq(TestWorkflowExecution)
      end
    end

    context 'when workflow_execution_class does not exist' do
      before { config.workflow_execution_class = 'NonExistentClass' }

      it 'raises an error' do
        expect { config.workflow_execution_model }.to raise_error(
          Avo::Workflows::Error,
          /Workflow execution class 'NonExistentClass' not found/
        )
      end
    end
  end

  describe '#enabled?' do
    it 'returns true when enabled is true' do
      config.enabled = true
      expect(config).to be_enabled
    end

    it 'returns false when enabled is false' do
      config.enabled = false
      expect(config).not_to be_enabled
    end
  end

  describe '#validate!' do
    context 'with valid configuration' do
      before do
        stub_const('User', Class.new)
        stub_const('Avo::Workflows::WorkflowExecution', Class.new)
      end

      it 'returns empty array' do
        expect(config.validate!).to be_empty
      end
    end

    context 'with invalid workflow execution class' do
      before { config.workflow_execution_class = 'NonExistent' }

      it 'returns validation errors' do
        errors = config.validate!
        expect(errors).to include(/Workflow execution class 'NonExistent' not found/)
      end
    end

    context 'with invalid user class' do
      before do
        stub_const('Avo::Workflows::WorkflowExecution', Class.new)
        config.user_class = 'NonExistentUser'
      end

      it 'returns validation errors' do
        errors = config.validate!
        expect(errors).to include(/User class 'NonExistentUser' not found/)
      end
    end

    context 'with blank workflow execution class' do
      before { config.instance_variable_set(:@workflow_execution_class, '') }

      it 'returns validation errors' do
        errors = config.validate!
        expect(errors).to include('workflow_execution_class cannot be blank')
      end
    end
  end

  describe '#valid?' do
    context 'with valid configuration' do
      before do
        stub_const('User', Class.new)
        stub_const('Avo::Workflows::WorkflowExecution', Class.new)
      end

      it 'returns true' do
        expect(config).to be_valid
      end
    end

    context 'with invalid configuration' do
      before { config.workflow_execution_class = 'NonExistent' }

      it 'returns false' do
        expect(config).not_to be_valid
      end
    end
  end
end