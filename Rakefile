# frozen_string_literal: true

require "bundler/gem_tasks"
require "rspec/core/rake_task"

RSpec::Core::RakeTask.new(:spec)

# Documentation tasks
namespace :docs do
  desc "Generate all documentation"
  task :generate do
    require_relative 'lib/avo/workflows'
    
    generator = Avo::Workflows::Documentation::Generator.new
    results = generator.generate_all_docs
    
    puts "Documentation generated successfully!"
    
    if results[:api_docs][:status] == :success
      puts "API docs: #{results[:api_docs][:output_path]}"
      puts "  - Modules: #{results[:api_docs][:modules_documented]}"
      puts "  - Classes: #{results[:api_docs][:classes_documented]}"
      puts "  - Methods: #{results[:api_docs][:methods_documented]}"
    end
    
    if results[:workflow_docs][:status] == :success
      puts "Workflow docs: #{results[:workflow_docs][:output_path]}"
      puts "  - Workflows: #{results[:workflow_docs][:workflows_documented]}"
    end
    
    if results[:usage_examples][:status] == :success
      puts "Examples: #{results[:usage_examples][:output_path]}"
      puts "  - Examples: #{results[:usage_examples][:examples_generated]}"
    end
    
    puts "Performance guide: #{results[:performance_docs][:output_path]}"
    puts "Troubleshooting: #{results[:troubleshooting][:output_path]}"
    puts "Main index: #{results[:index][:output_path]}"
  end
  
  desc "Generate API documentation only"
  task :api do
    require_relative 'lib/avo/workflows'
    
    generator = Avo::Workflows::Documentation::Generator.new
    result = generator.generate_api_docs
    
    if result[:status] == :success
      puts "API documentation generated: #{result[:output_path]}"
    else
      puts "Failed to generate API docs: #{result[:message]}"
    end
  end
  
  desc "Serve documentation locally"
  task :serve, [:port] do |t, args|
    port = args[:port] || 3001
    require_relative 'lib/avo/workflows'
    
    puts "Starting documentation server on port #{port}..."
    Avo::Workflows::Documentation::Server.start(port: port.to_i)
  end
  
  desc "Clean generated documentation"
  task :clean do
    require 'fileutils'
    FileUtils.rm_rf('doc')
    puts "Documentation cleaned"
  end
end

# Performance tasks
namespace :performance do
  desc "Run performance benchmarks"
  task :benchmark do
    puts "Running performance benchmarks..."
    
    # This would run comprehensive benchmarks
    # For now, just indicate the capability exists
    puts "Performance benchmarking available via Avo::Workflows::Performance::Benchmark"
    puts "Use: benchmark = Avo::Workflows::Performance::Benchmark.new"
    puts "Then: benchmark.load_test(WorkflowClass, concurrent_executions: 10)"
  end
  
  desc "Generate performance report"
  task :report do
    puts "Performance monitoring available via Avo::Workflows::Performance::Monitor"
    puts "Use: monitor = Avo::Workflows::Performance::Monitor.new(workflow_execution)"
    puts "Then: report = monitor.performance_report"
  end
end

# Default task
task default: :spec
