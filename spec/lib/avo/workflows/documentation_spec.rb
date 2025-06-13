# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Avo::Workflows::Documentation do
  let(:temp_dir) { Dir.mktmpdir }
  let(:generator) { Avo::Workflows::Documentation::Generator.new(output_dir: temp_dir) }

  after do
    FileUtils.rm_rf(temp_dir) if Dir.exist?(temp_dir)
  end

  describe Avo::Workflows::Documentation::Generator do
    describe '#initialize' do
      it 'sets up generator with default options' do
        expect(generator.output_dir).to eq(temp_dir)
        expect(generator.options[:include_private]).to eq(false)
        expect(generator.options[:include_examples]).to eq(true)
        expect(generator.options[:template]).to eq('default')
      end

      it 'accepts custom options' do
        custom_generator = Avo::Workflows::Documentation::Generator.new(
          output_dir: temp_dir,
          include_private: true,
          template: 'custom'
        )
        
        expect(custom_generator.options[:include_private]).to eq(true)
        expect(custom_generator.options[:template]).to eq('custom')
      end
    end

    describe '#generate_all_docs' do
      it 'generates all documentation types' do
        results = generator.generate_all_docs

        expect(results).to include(
          :api_docs,
          :workflow_docs,
          :usage_examples,
          :performance_docs,
          :troubleshooting,
          :index
        )
        
        expect(results[:workflow_docs][:status]).to eq(:success)
        expect(results[:usage_examples][:status]).to eq(:success)
        expect(results[:performance_docs][:status]).to eq(:success)
        expect(results[:troubleshooting][:status]).to eq(:success)
        expect(results[:index][:status]).to eq(:success)
      end

      it 'creates output directories' do
        generator.generate_all_docs

        expect(Dir.exist?(File.join(temp_dir, 'workflows'))).to be true
        expect(Dir.exist?(File.join(temp_dir, 'examples'))).to be true
        expect(File.exist?(File.join(temp_dir, 'performance.md'))).to be true
        expect(File.exist?(File.join(temp_dir, 'troubleshooting.md'))).to be true
        expect(File.exist?(File.join(temp_dir, 'index.md'))).to be true
      end
    end

    describe '#generate_api_docs' do
      context 'when YARD is available' do
        before do
          # Mock YARD availability
          stub_const('YARD', Module.new)
          allow(YARD).to receive(:parse)
          
          yard_cli = double('YARD::CLI::Yardoc')
          allow(yard_cli).to receive(:run)
          stub_const('YARD::CLI::Yardoc', yard_cli)
          
          yard_registry = double('YARD::Registry')
          allow(yard_registry).to receive(:clear)
          allow(yard_registry).to receive(:all).and_return([])
          stub_const('YARD::Registry', yard_registry)
        end

        it 'generates API documentation successfully' do
          result = generator.generate_api_docs

          expect(result[:status]).to eq(:success)
          expect(result).to include(
            :files_processed,
            :output_path,
            :modules_documented,
            :classes_documented,
            :methods_documented
          )
        end
      end

      context 'when YARD is not available' do
        it 'returns error status' do
          result = generator.generate_api_docs

          expect(result[:status]).to eq(:error)
          expect(result[:message]).to include('YARD gem not available')
        end
      end
    end

    describe '#generate_workflow_docs' do
      it 'generates workflow documentation' do
        result = generator.generate_workflow_docs

        expect(result[:status]).to eq(:success)
        expect(result).to include(
          :workflows_documented,
          :output_path,
          :workflow_docs
        )
        expect(result[:workflows_documented]).to be >= 0
        expect(result[:output_path]).to eq(File.join(temp_dir, 'workflows'))
      end

      it 'creates workflow index file' do
        generator.generate_workflow_docs

        index_file = File.join(temp_dir, 'workflows', 'index.md')
        expect(File.exist?(index_file)).to be true
        
        content = File.read(index_file)
        expect(content).to include('# Workflow Documentation')
        expect(content).to include('## Available Workflows')
      end
    end

    describe '#generate_usage_examples' do
      it 'generates usage examples' do
        result = generator.generate_usage_examples

        expect(result[:status]).to eq(:success)
        expect(result[:examples_generated]).to eq(5)
        expect(result[:examples]).to include(
          :basic_workflow,
          :advanced_workflow,
          :performance_monitoring,
          :error_handling,
          :debugging
        )
      end

      it 'creates example files' do
        generator.generate_usage_examples

        examples_dir = File.join(temp_dir, 'examples')
        expect(Dir.exist?(examples_dir)).to be true
        expect(File.exist?(File.join(examples_dir, 'index.md'))).to be true
        expect(File.exist?(File.join(examples_dir, 'basic_workflow.md'))).to be true
        expect(File.exist?(File.join(examples_dir, 'advanced_workflow.md'))).to be true
      end

      it 'includes proper example content' do
        generator.generate_usage_examples

        basic_example = File.read(File.join(temp_dir, 'examples', 'basic_workflow.md'))
        expect(basic_example).to include('# Basic Workflow Example')
        expect(basic_example).to include('class SimpleApprovalWorkflow')
        expect(basic_example).to include('```ruby')
      end
    end

    describe '#generate_performance_docs' do
      it 'generates performance documentation' do
        result = generator.generate_performance_docs

        expect(result[:status]).to eq(:success)
        expect(result[:output_path]).to eq(File.join(temp_dir, 'performance.md'))
        expect(result[:sections]).to include('monitoring', 'benchmarking', 'optimization', 'load_testing')
      end

      it 'creates performance documentation file' do
        generator.generate_performance_docs

        perf_file = File.join(temp_dir, 'performance.md')
        expect(File.exist?(perf_file)).to be true
        
        content = File.read(perf_file)
        expect(content).to include('# Performance Documentation')
        expect(content).to include('## Performance Monitoring')
        expect(content).to include('## Benchmarking')
        expect(content).to include('## Optimization')
      end
    end

    describe '#generate_troubleshooting_guide' do
      it 'generates troubleshooting guide' do
        result = generator.generate_troubleshooting_guide

        expect(result[:status]).to eq(:success)
        expect(result[:output_path]).to eq(File.join(temp_dir, 'troubleshooting.md'))
        expect(result[:sections]).to include('common_issues', 'debugging', 'error_recovery', 'performance_issues')
      end

      it 'creates troubleshooting guide file' do
        generator.generate_troubleshooting_guide

        guide_file = File.join(temp_dir, 'troubleshooting.md')
        expect(File.exist?(guide_file)).to be true
        
        content = File.read(guide_file)
        expect(content).to include('# Troubleshooting Guide')
        expect(content).to include('## Common Issues')
        expect(content).to include('Action Not Available Error')
        expect(content).to include('Performance Issues')
      end
    end
  end

  describe Avo::Workflows::Documentation::Server do
    describe '.start' do
      it 'attempts to start documentation server' do
        # Mock WEBrick to avoid actually starting a server
        webrick_server = double('WEBrick::HTTPServer')
        allow(webrick_server).to receive(:start)
        
        webrick_class = double('WEBrick::HTTPServer class')
        allow(webrick_class).to receive(:new).and_return(webrick_server)
        stub_const('WEBrick::HTTPServer', webrick_class)

        expect { Avo::Workflows::Documentation::Server.start(port: 3002) }.not_to raise_error
      end

      it 'handles missing WEBrick gracefully' do
        # Hide WEBrick constant to simulate missing gem
        hide_const('WEBrick') if defined?(WEBrick)
        
        expect {
          Avo::Workflows::Documentation::Server.start(port: 3002)
        }.to output(/WEBrick not available/).to_stdout
      end
    end
  end

  describe Avo::Workflows::Documentation::CLI do
    describe '.run' do
      it 'handles generate command' do
        allow(Avo::Workflows::Documentation::Generator).to receive(:new).and_return(generator)
        allow(generator).to receive(:generate_all_docs).and_return({
          api_docs: { status: :success, output_path: '/tmp/api' },
          workflow_docs: { status: :success, output_path: '/tmp/workflows' }
        })

        expect {
          Avo::Workflows::Documentation::CLI.run(['generate'])
        }.to output(/Documentation generated successfully!/).to_stdout
      end

      it 'handles serve command' do
        allow(Avo::Workflows::Documentation::Server).to receive(:start)

        expect {
          Avo::Workflows::Documentation::CLI.run(['serve', '3003'])
        }.not_to raise_error
      end

      it 'handles clean command' do
        # Create a temporary doc directory to clean
        doc_dir = File.join(temp_dir, 'doc')
        FileUtils.mkdir_p(doc_dir)
        File.write(File.join(doc_dir, 'test.txt'), 'test')
        
        allow(FileUtils).to receive(:rm_rf).with('doc')

        expect {
          Avo::Workflows::Documentation::CLI.run(['clean'])
        }.to output(/Documentation cleaned/).to_stdout
      end

      it 'shows usage for unknown commands' do
        expect {
          Avo::Workflows::Documentation::CLI.run(['unknown'])
        }.to output(/Avo Workflows Documentation Tool/).to_stdout
      end

      it 'shows usage for no arguments' do
        expect {
          Avo::Workflows::Documentation::CLI.run([])
        }.to output(/Usage:/).to_stdout
      end
    end

    describe '.usage_message' do
      it 'returns comprehensive usage information' do
        message = Avo::Workflows::Documentation::CLI.usage_message

        expect(message).to include('Avo Workflows Documentation Tool')
        expect(message).to include('generate')
        expect(message).to include('serve')
        expect(message).to include('clean')
      end
    end
  end

  describe 'Documentation content quality' do
    it 'generates markdown with proper structure' do
      generator.generate_usage_examples

      basic_example = File.read(File.join(temp_dir, 'examples', 'basic_workflow.md'))
      
      # Check for markdown headers
      expect(basic_example).to include('# Basic Workflow Example')
      expect(basic_example).to include('## 1. Define the Workflow')
      expect(basic_example).to include('## 2. Use the Workflow')
      
      # Check for code blocks
      expect(basic_example).to include('```ruby')
      expect(basic_example).to include('class SimpleApprovalWorkflow')
      expect(basic_example).to include('step :draft')
    end

    it 'includes comprehensive performance documentation' do
      generator.generate_performance_docs

      perf_content = File.read(File.join(temp_dir, 'performance.md'))
      
      expect(perf_content).to include('Performance::Monitor')
      expect(perf_content).to include('Performance::Benchmark')
      expect(perf_content).to include('PerformanceOptimizer')
      expect(perf_content).to include('QueryOptimizer')
      expect(perf_content).to include('MemoryOptimizer')
    end

    it 'provides actionable troubleshooting guidance' do
      generator.generate_troubleshooting_guide

      troubleshooting_content = File.read(File.join(temp_dir, 'troubleshooting.md'))
      
      expect(troubleshooting_content).to include('ActionNotAvailableError')
      expect(troubleshooting_content).to include('ValidationError')
      expect(troubleshooting_content).to include('available_actions')
      expect(troubleshooting_content).to include('recovery.rollback_to_recovery_point')
    end
  end

  describe 'File organization' do
    it 'creates proper directory structure' do
      generator.generate_all_docs

      expect(Dir.exist?(File.join(temp_dir, 'workflows'))).to be true
      expect(Dir.exist?(File.join(temp_dir, 'examples'))).to be true
      expect(File.exist?(File.join(temp_dir, 'index.md'))).to be true
      expect(File.exist?(File.join(temp_dir, 'performance.md'))).to be true
      expect(File.exist?(File.join(temp_dir, 'troubleshooting.md'))).to be true
    end

    it 'creates navigable index pages' do
      generator.generate_all_docs

      index_content = File.read(File.join(temp_dir, 'index.md'))
      
      expect(index_content).to include('[API Documentation](api/index.html)')
      expect(index_content).to include('[Workflow Documentation](workflows/index.html)')
      expect(index_content).to include('[Usage Examples](examples/index.html)')
      expect(index_content).to include('[Performance Guide](performance.html)')
      expect(index_content).to include('[Troubleshooting](troubleshooting.html)')
    end
  end
end