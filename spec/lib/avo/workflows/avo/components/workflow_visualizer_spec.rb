# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Avo::Workflows::Avo::Components::WorkflowVisualizer', type: :component do
  before(:all) do
    load File.expand_path('../../../../../../lib/avo/workflows/avo/components/workflow_visualizer.rb', __dir__)
  end

  let(:user) { User.create!(name: 'Test User', email: 'test@example.com') }
  let(:document) { Post.create!(title: 'Test Document', content: 'Test content', user: user) }
  let(:workflow_execution) do
    Avo::Workflows::WorkflowExecution.create!(
      workflow_class: 'TestWorkflow',
      workflowable: document,
      current_step: 'draft'
    )
  end
  let(:component) { Avo::Workflows::Avo::Components::WorkflowVisualizer.new(workflow_execution: workflow_execution) }

  describe 'initialization' do
    it 'accepts workflow execution' do
      expect(component.send(:workflow_execution)).to eq(workflow_execution)
    end

    it 'accepts options' do
      component = described_class.new(
        workflow_execution: workflow_execution,
        show_descriptions: true,
        orientation: :vertical,
        size: :large,
        interactive: true
      )

      expect(component.send(:show_descriptions)).to be_truthy
      expect(component.send(:orientation)).to eq(:vertical)
      expect(component.send(:size)).to eq(:large)
      expect(component.send(:interactive)).to be_truthy
    end

    it 'has default options' do
      expect(component.send(:show_descriptions)).to be_falsy
      expect(component.send(:orientation)).to eq(:horizontal)
      expect(component.send(:size)).to eq(:medium)
      expect(component.send(:interactive)).to be_falsy
    end
  end

  describe 'workflow analysis' do
    describe '#workflow_class' do
      it 'handles missing workflow class' do
        allow(Avo::Workflows::Registry).to receive(:find).and_return(nil)
        expect(component.send(:workflow_class)).to be_nil
      end
    end

    describe '#workflow_steps' do
      it 'returns empty array when no workflow class' do
        allow(component).to receive(:workflow_class).and_return(nil)
        steps = component.send(:workflow_steps)
        expect(steps).to eq([])
      end
    end

    describe '#current_step_index' do
      it 'returns 0 for unknown steps' do
        allow(component).to receive(:workflow_steps).and_return(['step1', 'step2'])
        workflow_execution.update!(current_step: 'unknown_step')
        expect(component.send(:current_step_index)).to eq(0)
      end
    end
  end

  describe 'styling methods' do
    describe '#step_color' do
      it 'returns correct colors for each status' do
        expect(component.send(:step_color, 'completed')).to include('text-green-600')
        expect(component.send(:step_color, 'current')).to include('text-blue-600')
        expect(component.send(:step_color, 'failed')).to include('text-red-600')
        expect(component.send(:step_color, 'paused')).to include('text-yellow-600')
        expect(component.send(:step_color, 'pending')).to include('text-gray-400')
      end
    end

    describe '#step_icon' do
      it 'returns appropriate icons for each status' do
        expect(component.send(:step_icon, 'draft', 'completed')).to eq('check-circle')
        expect(component.send(:step_icon, 'draft', 'current')).to eq('play-circle')
        expect(component.send(:step_icon, 'draft', 'failed')).to eq('x-circle')
        expect(component.send(:step_icon, 'draft', 'paused')).to eq('pause-circle')
        expect(component.send(:step_icon, 'draft', 'pending')).to eq('circle')
      end
    end
  end

  describe '#progress_percentage' do
    it 'returns 100 for completed workflows' do
      workflow_execution.update!(status: 'completed')
      expect(component.send(:progress_percentage)).to eq(100)
    end

    it 'returns 0 for workflows with no steps' do
      allow(component).to receive(:workflow_steps).and_return([])
      expect(component.send(:progress_percentage)).to eq(0)
    end
  end
end