# frozen_string_literal: true

require 'spec_helper'
require 'tmpdir'
require 'fileutils'

RSpec.describe 'Workflow Generator' do
  let(:temp_dir) { Dir.mktmpdir }
  
  after do
    FileUtils.rm_rf(temp_dir)
  end

  it 'can instantiate the generator' do
    require 'generators/avo_workflows/workflow/workflow_generator'
    generator = AvoWorkflows::Generators::WorkflowGenerator.new(['test_workflow'])
    expect(generator).to be_a(AvoWorkflows::Generators::WorkflowGenerator)
  end

  it 'has the correct source root' do
    require 'generators/avo_workflows/workflow/workflow_generator'
    expect(AvoWorkflows::Generators::WorkflowGenerator.source_root).to end_with('lib/generators/avo_workflows/workflow/templates')
  end

  it 'has workflow template file' do
    require 'generators/avo_workflows/workflow/workflow_generator'
    template_path = File.join(AvoWorkflows::Generators::WorkflowGenerator.source_root, 'workflow.rb.erb')
    expect(File.exist?(template_path)).to be true
    
    content = File.read(template_path)
    expect(content).to include('<%= workflow_class_name %> < Avo::Workflows::Base')
  end

  it 'has workflow spec template file' do
    require 'generators/avo_workflows/workflow/workflow_generator'
    template_path = File.join(AvoWorkflows::Generators::WorkflowGenerator.source_root, 'workflow_spec.rb.erb')
    expect(File.exist?(template_path)).to be true
    
    content = File.read(template_path)
    expect(content).to include('RSpec.describe <%= workflow_class_name %>')
  end

  it 'generates correct workflow class name' do
    require 'generators/avo_workflows/workflow/workflow_generator'
    generator = AvoWorkflows::Generators::WorkflowGenerator.new(['approval'])
    expect(generator.send(:workflow_class_name)).to eq('ApprovalWorkflow')
  end

  it 'generates correct file name' do
    require 'generators/avo_workflows/workflow/workflow_generator'
    generator = AvoWorkflows::Generators::WorkflowGenerator.new(['approval'])
    expect(generator.send(:file_name)).to eq('approval')
  end

  it 'uses default steps when none provided' do
    require 'generators/avo_workflows/workflow/workflow_generator'
    generator = AvoWorkflows::Generators::WorkflowGenerator.new(['approval'])
    expected_steps = %w[draft pending_review approved]
    expect(generator.send(:workflow_steps)).to eq(expected_steps)
  end

  it 'uses custom steps when provided' do
    require 'generators/avo_workflows/workflow/workflow_generator'
    generator = AvoWorkflows::Generators::WorkflowGenerator.new(['order', 'submitted', 'processing', 'completed'])
    expected_steps = %w[submitted processing completed]
    expect(generator.send(:workflow_steps)).to eq(expected_steps)
  end
end