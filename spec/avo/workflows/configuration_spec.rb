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
end