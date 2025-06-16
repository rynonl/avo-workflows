# frozen_string_literal: true

require 'spec_helper'
require 'tmpdir'
require 'fileutils'
require 'generators/avo_workflows/install/install_generator'

RSpec.describe AvoWorkflows::Generators::InstallGenerator do
  let(:temp_dir) { Dir.mktmpdir }
  
  after do
    FileUtils.rm_rf(temp_dir)
  end

  before do
    # Set up basic directory structure
    FileUtils.mkdir_p(File.join(temp_dir, 'app', 'avo', 'workflows'))
    FileUtils.mkdir_p(File.join(temp_dir, 'config', 'initializers'))
    FileUtils.mkdir_p(File.join(temp_dir, 'db', 'migrate'))
  end

  it 'can instantiate the generator' do
    generator = AvoWorkflows::Generators::InstallGenerator.new
    expect(generator).to be_a(AvoWorkflows::Generators::InstallGenerator)
  end

  it 'has the correct source root' do
    expect(AvoWorkflows::Generators::InstallGenerator.source_root).to end_with('lib/generators/avo_workflows/install/templates')
  end

  it 'has migration template with correct content' do
    template_path = File.join(AvoWorkflows::Generators::InstallGenerator.source_root, 'create_avo_workflow_executions.rb.erb')
    expect(File.exist?(template_path)).to be true
    
    content = File.read(template_path)
    expect(content).to include('create_table :avo_workflow_executions')
    expect(content).to include('t.string :workflow_class, null: false')
    expect(content).to include('t.references :workflowable, polymorphic: true')
  end

  it 'has initializer template with correct content' do
    template_path = File.join(AvoWorkflows::Generators::InstallGenerator.source_root, 'initializer.rb.erb')
    expect(File.exist?(template_path)).to be true
    
    content = File.read(template_path)
    expect(content).to include('Avo::Workflows.configure')
  end
end