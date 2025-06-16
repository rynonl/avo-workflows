# frozen_string_literal: true

require 'spec_helper'
require 'tmpdir'
require 'fileutils'
require 'generators/avo_workflows/workflow/workflow_generator'

RSpec.describe AvoWorkflows::Generators::WorkflowGenerator do
  let(:temp_dir) { Dir.mktmpdir }
  
  after do
    FileUtils.rm_rf(temp_dir)
  end

  before do
    # Set up basic directory structure
    FileUtils.mkdir_p(File.join(temp_dir, 'app', 'avo', 'workflows'))
    FileUtils.mkdir_p(File.join(temp_dir, 'spec', 'avo', 'workflows'))
  end

  it 'can instantiate the generator with arguments' do
    generator = AvoWorkflows::Generators::WorkflowGenerator.new(['test_workflow'])
    expect(generator).to be_a(AvoWorkflows::Generators::WorkflowGenerator)
  end

  it 'has the correct source root' do
    expect(AvoWorkflows::Generators::WorkflowGenerator.source_root).to end_with('lib/generators/avo_workflows/workflow/templates')
  end

  it 'has workflow template with correct content' do
    template_path = File.join(AvoWorkflows::Generators::WorkflowGenerator.source_root, 'workflow.rb.erb')
    expect(File.exist?(template_path)).to be true
    
    content = File.read(template_path)
    expect(content).to include('class <%= workflow_class_name %> < Avo::Workflows::Base')
    expect(content).to include('step :')
  end
end