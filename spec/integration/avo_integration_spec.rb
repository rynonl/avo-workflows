# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Avo Integration', type: :integration do
  describe 'when Avo mocks are available' do
    before(:all) do
      # Mocks are loaded by support/avo_mocks.rb
    end

    it 'loads WorkflowResource without errors' do
      expect {
        require_relative '../../lib/avo/workflows/avo/workflow_resource'
      }.not_to raise_error
    end

    it 'loads WorkflowStepPanel without errors' do
      expect {
        require_relative '../../lib/avo/workflows/avo/panels/workflow_step_panel'
      }.not_to raise_error
    end

    it 'loads WorkflowVisualizer without errors' do
      expect {
        require_relative '../../lib/avo/workflows/avo/components/workflow_visualizer'
      }.not_to raise_error
    end

    it 'loads filters without errors' do
      expect {
        require_relative '../../lib/avo/workflows/avo/filters/workflow_class_filter'
        require_relative '../../lib/avo/workflows/avo/filters/status_filter'
        require_relative '../../lib/avo/workflows/avo/filters/current_step_filter'
      }.not_to raise_error
    end

    it 'loads actions without errors' do
      expect {
        require_relative '../../lib/avo/workflows/avo/actions/perform_workflow_action'
        require_relative '../../lib/avo/workflows/avo/actions/assign_workflow'
      }.not_to raise_error
    end

    it 'loads fields without errors' do
      expect {
        require_relative '../../lib/avo/workflows/avo/fields/workflow_progress_field'
        require_relative '../../lib/avo/workflows/avo/fields/workflow_actions_field'
        require_relative '../../lib/avo/workflows/avo/fields/workflow_timeline_field'
      }.not_to raise_error
    end

    it 'creates WorkflowResource instances' do
      require_relative '../../lib/avo/workflows/avo/workflow_resource'
      
      expect {
        Avo::Workflows::Avo::WorkflowResource.new
      }.not_to raise_error
    end

    it 'WorkflowResource extends Avo::BaseResource' do
      require_relative '../../lib/avo/workflows/avo/workflow_resource'
      
      expect(Avo::Workflows::Avo::WorkflowResource.superclass).to eq(Avo::BaseResource)
    end

    it 'WorkflowResource has correct model class' do
      require_relative '../../lib/avo/workflows/avo/workflow_resource'
      
      expect(Avo::Workflows::Avo::WorkflowResource.model_class).to eq(Avo::Workflows::WorkflowExecution)
    end
  end
end