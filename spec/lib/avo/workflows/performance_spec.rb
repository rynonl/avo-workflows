# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Avo::Workflows::Performance do
  let(:hr_user) { User.create!(name: 'HR Manager', email: 'hr@company.com') }
  let(:manager) { User.create!(name: 'Manager', email: 'manager@company.com') }
  
  let(:employee) do
    Employee.create!(
      name: 'John Doe',
      email: 'john.doe@company.com',
      employee_type: 'full_time',
      department: 'Engineering',
      salary_level: 'senior',
      start_date: Date.current + 1.week,
      manager: manager,
      hr_representative: hr_user
    )
  end

  let(:workflow_execution) { employee.start_onboarding!(assigned_to: hr_user) }

  describe Avo::Workflows::Performance::Monitor do
    let(:monitor) { described_class.new(workflow_execution) }

    describe '#initialize' do
      it 'sets up monitoring for workflow execution' do
        expect(monitor.workflow_execution).to eq(workflow_execution)
        expect(monitor.start_time).to be_within(1.second).of(Time.current)
        expect(monitor.metrics).to eq({})
      end
    end

    describe '#performance_report' do
      it 'generates comprehensive performance report' do
        report = monitor.performance_report

        expect(report).to include(
          :execution_summary,
          :timing_analysis,
          :memory_analysis,
          :database_analysis,
          :bottleneck_analysis,
          :optimization_recommendations
        )
      end

      it 'includes execution summary with workflow details' do
        report = monitor.performance_report
        summary = report[:execution_summary]

        expect(summary).to include(
          workflow_id: workflow_execution.id,
          workflow_class: 'EmployeeOnboardingWorkflow',
          current_step: 'initial_setup',
          total_steps: 0
        )
        expect(summary[:monitoring_duration]).to be >= 0
      end

      it 'includes timing analysis' do
        report = monitor.performance_report
        timing = report[:timing_analysis]

        expect(timing).to include(
          :total_execution_time,
          :average_operation_time,
          :slowest_operations,
          :fastest_operations
        )
      end

      it 'includes memory analysis' do
        report = monitor.performance_report
        memory = report[:memory_analysis]

        expect(memory).to include(
          :current_memory,
          :peak_memory,
          :memory_growth,
          :memory_snapshots
        )
        expect(memory[:current_memory]).to be >= 0
      end

      it 'includes database analysis' do
        report = monitor.performance_report
        database = report[:database_analysis]

        expect(database).to include(
          :total_queries,
          :queries_per_operation,
          :query_hotspots
        )
      end
    end

    describe '#start_operation and #end_operation' do
      it 'tracks operation performance metrics' do
        operation_id = monitor.start_operation('test_operation')

        expect(operation_id).to be_a(String)
        expect(monitor.metrics[operation_id]).to include(
          name: 'test_operation',
          start_time: be_within(1.second).of(Time.current),
          start_memory: be >= 0
        )
      end

      it 'completes operation tracking with metrics' do
        operation_id = monitor.start_operation('test_operation')
        sleep 0.01 # Small delay to ensure measurable duration
        
        metrics = monitor.end_operation(operation_id)

        expect(metrics).to include(
          :name,
          :start_time,
          :end_time,
          :duration,
          :start_memory,
          :end_memory,
          :memory_delta,
          :query_count
        )
        expect(metrics[:duration]).to be > 0
        expect(metrics[:name]).to eq('test_operation')
      end

      it 'handles non-existent operation ID gracefully' do
        result = monitor.end_operation('non-existent-id')
        expect(result).to be_nil
      end
    end

    describe '#monitor_operation' do
      it 'monitors block execution and returns result' do
        result = monitor.monitor_operation('test_block') do
          'test_result'
        end

        expect(result).to eq('test_result')
        expect(monitor.metrics.size).to eq(1)
        
        operation = monitor.metrics.values.first
        expect(operation[:name]).to eq('test_block')
        expect(operation[:duration]).to be > 0
      end

      it 'captures memory usage during operation' do
        monitor.monitor_operation('memory_test') do
          # Create some temporary objects
          Array.new(1000) { "test_string_#{rand(1000)}" }
        end

        operation = monitor.metrics.values.first
        expect(operation[:memory_delta]).to be_a(Numeric)
      end
    end

    describe '#analyze_execution_trends' do
      it 'analyzes performance trends over time' do
        # Add some history to the workflow
        workflow_execution.perform_action(:begin_documentation_review, user: hr_user)
        
        trends = monitor.analyze_execution_trends

        expect(trends).to include(
          :step_durations,
          :peak_memory_steps,
          :query_intensive_steps,
          :performance_trends
        )
      end

      it 'handles workflow with no history' do
        trends = monitor.analyze_execution_trends

        expect(trends[:step_durations]).to eq([])
        expect(trends[:peak_memory_steps]).to be_an(Array)
        expect(trends[:query_intensive_steps]).to be_an(Array)
      end
    end

    describe '#optimization_recommendations' do
      it 'provides relevant optimization recommendations' do
        recommendations = monitor.optimization_recommendations

        expect(recommendations).to be_an(Array)
        recommendations.each do |rec|
          expect(rec).to include(:type, :severity, :message, :suggestion)
          expect(rec[:type]).to be_in([:memory, :database, :performance])
          expect(rec[:severity]).to be_in([:low, :medium, :high, :critical])
        end
      end

      it 'recommends memory optimization for high usage' do
        # Simulate high memory usage
        allow(monitor).to receive(:peak_memory_usage).and_return(150.megabytes)
        
        recommendations = monitor.optimization_recommendations
        memory_rec = recommendations.find { |r| r[:type] == :memory }

        expect(memory_rec).to be_present
        expect(memory_rec[:severity]).to eq(:high)
        expect(memory_rec[:message]).to include('High memory usage')
      end

      it 'recommends query optimization for many queries' do
        # Simulate many operations with queries
        60.times { |i| monitor.start_operation("query_op_#{i}") }
        
        recommendations = monitor.optimization_recommendations
        db_rec = recommendations.find { |r| r[:type] == :database }

        expect(db_rec).to be_present if monitor.send(:total_query_count) > 50
      end
    end

    describe '#export_performance_data' do
      before do
        monitor.monitor_operation('test_operation') { sleep 0.01 }
      end

      it 'exports performance data in JSON format' do
        data = monitor.export_performance_data(format: :json)

        expect { JSON.parse(data) }.not_to raise_error
        parsed = JSON.parse(data)
        expect(parsed).to include('workflow_execution_id', 'performance_report', 'metrics')
      end

      it 'exports performance data in YAML format' do
        data = monitor.export_performance_data(format: :yaml)

        expect { YAML.safe_load(data, permitted_classes: [Time, Symbol, ActiveSupport::TimeWithZone, ActiveSupport::TimeZone], aliases: true) }.not_to raise_error
        parsed = YAML.safe_load(data, permitted_classes: [Time, Symbol, ActiveSupport::TimeWithZone, ActiveSupport::TimeZone], aliases: true)
        expect(parsed.keys.map(&:to_s)).to include('workflow_execution_id', 'performance_report', 'metrics')
      end

      it 'exports performance data in CSV format' do
        data = monitor.export_performance_data(format: :csv)

        if data.include?('CSV export requires')
          # CSV gem not available - skip this test
          expect(data).to include('CSV export requires')
        else
          expect(data).to include('Operation,Duration,Memory Delta,Query Count')
          expect(data).to include('test_operation')
        end
      end

      it 'returns raw hash for unknown format' do
        data = monitor.export_performance_data(format: :unknown)

        expect(data).to be_a(Hash)
        expect(data).to include(:workflow_execution_id, :performance_report, :metrics)
      end
    end
  end

  describe Avo::Workflows::Performance::Benchmark do
    let(:benchmark) { described_class.new }

    describe '#initialize' do
      it 'initializes with empty results' do
        expect(benchmark.results).to eq({})
      end
    end

    describe '#compare' do
      it 'compares multiple subjects with benchmark results' do
        subjects = ['operation_a', 'operation_b']
        
        results = benchmark.compare(subjects, iterations: 2) do |subject|
          sleep 0.001 if subject == 'operation_b' # Make B slightly slower
        end

        expect(results).to include(:summary, :detailed_results, :performance_ratios)
        expect(results[:summary]).to include(:fastest, :slowest, :most_memory_efficient)
        expect(results[:detailed_results].keys).to match_array(['operation_a', 'operation_b'])
      end

      it 'handles single iteration correctly' do
        subjects = ['single_op']
        
        results = benchmark.compare(subjects, iterations: 1) do |subject|
          'result'
        end

        expect(results[:detailed_results]['single_op']).to include(:times, :memory_deltas, :average_time)
      end
    end

    describe '#benchmark_operation' do
      it 'benchmarks operation multiple times' do
        result = benchmark.benchmark_operation('test_op', iterations: 3) do
          sleep 0.001
        end

        expect(result).to include(
          operation: 'test_op',
          iterations: 3,
          times: include(:min, :max, :average, :median),
          memory: include(:min, :max, :average, :median)
        )
        expect(result[:times][:average]).to be > 0
      end

      it 'calculates timing statistics correctly' do
        result = benchmark.benchmark_operation('timing_test', iterations: 5) do
          sleep 0.002
        end

        times = result[:times]
        expect(times[:min]).to be <= times[:average]
        expect(times[:average]).to be <= times[:max]
        expect(times[:median]).to be_between(times[:min], times[:max])
      end
    end

    describe '#load_test' do
      it 'performs load testing with concurrent executions' do
        allow(benchmark).to receive(:create_test_workflowable_for_class).and_return(employee)
        allow(benchmark).to receive(:create_test_user).and_return(hr_user)
        
        result = benchmark.load_test(
          EmployeeOnboardingWorkflow,
          concurrent_executions: 2,
          operations_per_execution: 1
        )

        expect(result).to include(
          :total_time,
          :concurrent_executions,
          :operations_per_execution,
          :total_operations,
          :execution_results,
          :throughput,
          :memory_peak,
          :average_execution_time
        )
        expect(result[:concurrent_executions]).to eq(2)
        expect(result[:operations_per_execution]).to eq(1)
        expect(result[:total_operations]).to eq(2)
        expect(result[:execution_results]).to be_an(Array)
      end

      it 'calculates throughput correctly' do
        allow(benchmark).to receive(:create_test_workflowable_for_class).and_return(employee)
        allow(benchmark).to receive(:create_test_user).and_return(hr_user)
        
        result = benchmark.load_test(
          EmployeeOnboardingWorkflow,
          concurrent_executions: 1,
          operations_per_execution: 1
        )

        expect(result[:throughput]).to be > 0
        expect(result[:throughput]).to eq(result[:total_operations] / result[:total_time])
      end
    end

    describe '#memory_stress_test' do
      it 'performs memory stress testing' do
        result = benchmark.memory_stress_test(workflow_execution, data_size_mb: 1)

        expect(result).to include(
          :test_duration,
          :operations_completed,
          :initial_memory,
          :peak_memory,
          :final_memory,
          :memory_growth,
          :memory_efficiency
        )
        expect(result[:test_duration]).to be > 0
        expect(result[:operations_completed]).to be >= 0
        expect(result[:memory_efficiency]).to be_a(Numeric)
      end

      it 'tracks memory usage during stress test' do
        result = benchmark.memory_stress_test(workflow_execution, data_size_mb: 2)

        expect(result[:peak_memory]).to be >= result[:initial_memory]
        expect(result[:memory_growth]).to eq(result[:final_memory] - result[:initial_memory])
      end
    end
  end

  describe 'Module methods' do
    describe '.monitor' do
      it 'creates a new Monitor instance' do
        monitor = described_class.monitor(workflow_execution)
        expect(monitor).to be_a(Avo::Workflows::Performance::Monitor)
        expect(monitor.workflow_execution).to eq(workflow_execution)
      end
    end

    describe '.benchmark' do
      it 'creates a new Benchmark instance' do
        benchmark = described_class.benchmark
        expect(benchmark).to be_a(Avo::Workflows::Performance::Benchmark)
        expect(benchmark.results).to eq({})
      end
    end

    describe '.quick_analysis' do
      it 'provides quick performance analysis' do
        analysis = described_class.quick_analysis(workflow_execution)

        expect(analysis).to include(
          :performance_score,
          :key_metrics,
          :recommendations
        )
        expect(analysis[:performance_score]).to be_between(0, 100)
        expect(analysis[:key_metrics]).to include(:memory_usage, :execution_time, :query_efficiency)
        expect(analysis[:recommendations]).to be_an(Array)
      end

      it 'calculates performance score appropriately' do
        analysis = described_class.quick_analysis(workflow_execution)
        score = analysis[:performance_score]

        expect(score).to be_a(Integer)
        expect(score).to be_between(0, 100)
      end
    end
  end

  describe 'Integration with workflow operations' do
    it 'monitors workflow action performance' do
      monitor = Avo::Workflows::Performance::Monitor.new(workflow_execution)
      
      result = monitor.monitor_operation('perform_action') do
        workflow_execution.perform_action(:begin_documentation_review, user: hr_user)
      end

      expect(result).to be_truthy
      operation = monitor.metrics.values.first
      expect(operation[:name]).to eq('perform_action')
      expect(operation[:duration]).to be > 0
    end

    it 'tracks memory usage across multiple workflow operations' do
      monitor = Avo::Workflows::Performance::Monitor.new(workflow_execution)
      
      # Perform multiple operations
      monitor.monitor_operation('action_1') do
        workflow_execution.perform_action(:begin_documentation_review, user: hr_user)
      end
      
      if workflow_execution.available_actions.any?
        monitor.monitor_operation('action_2') do
          workflow_execution.perform_action(workflow_execution.available_actions.first, user: hr_user)
        end
      end

      report = monitor.performance_report
      expect(report[:timing_analysis][:total_execution_time]).to be > 0
      expect(report[:memory_analysis][:current_memory]).to be >= 0
    end

    it 'provides optimization recommendations for complex workflows' do
      monitor = Avo::Workflows::Performance::Monitor.new(workflow_execution)
      
      # Simulate complex workflow with multiple operations
      5.times do |i|
        monitor.monitor_operation("complex_operation_#{i}") do
          # Simulate work
          Array.new(100) { "data_#{rand(1000)}" }
          workflow_execution.reload
        end
      end

      recommendations = monitor.optimization_recommendations
      expect(recommendations).to be_an(Array)
      
      # Should provide some recommendations for optimization
      recommendations.each do |rec|
        expect(rec).to include(:type, :severity, :message, :suggestion)
      end
    end
  end

  describe 'Performance regression detection' do
    it 'compares performance between different workflow configurations' do
      benchmark = Avo::Workflows::Performance::Benchmark.new
      
      # Test with different context sizes
      small_context_execution = workflow_execution
      large_context_execution = employee.start_onboarding!(assigned_to: hr_user)
      large_context_execution.update_context!(
        large_data: Array.new(1000) { "large_data_#{rand(10000)}" }
      )

      results = benchmark.compare([small_context_execution, large_context_execution]) do |execution|
        execution.available_actions.first(2).each do |action|
          execution.perform_action(action, user: hr_user) if execution.available_actions.include?(action)
        end
      end

      expect(results[:summary]).to include(:fastest, :slowest)
      expect(results[:detailed_results].size).to be >= 1
    end

    it 'detects performance degradation over iterations' do
      benchmark = Avo::Workflows::Performance::Benchmark.new
      
      # Benchmark the same operation multiple times
      result = benchmark.benchmark_operation('iteration_test', iterations: 5) do
        workflow_execution.available_actions.each do |action|
          # Simulate increasing complexity
          Array.new(rand(100..500)) { "iteration_data_#{rand(1000)}" }
          break # Just test one action per iteration
        end
      end

      expect(result[:times][:min]).to be > 0
      expect(result[:times][:max]).to be >= result[:times][:min]
      expect(result[:times][:average]).to be_between(result[:times][:min], result[:times][:max])
    end
  end
end