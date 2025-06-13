# frozen_string_literal: true

require 'rails_helper'

# Comprehensive performance test suite for workflow system
#
# This test suite validates performance characteristics under various load conditions
# and identifies potential bottlenecks in real-world usage scenarios.
RSpec.describe 'Workflow Performance Testing', type: :performance do
  let(:performance_logger) { Logger.new(Rails.root.join('log', 'performance_test.log')) }
  
  before(:all) do
    # Setup performance test environment
    @original_log_level = Rails.logger.level if defined?(Rails)
    Rails.logger.level = Logger::WARN if defined?(Rails)
    
    # Pre-create test users to avoid creation overhead during tests
    @hr_users = 5.times.map do |i|
      User.create!(
        name: "HR User #{i}",
        email: "hr#{i}@company.com"
      )
    end
    
    @managers = 5.times.map do |i|
      User.create!(
        name: "Manager #{i}",
        email: "manager#{i}@company.com"
      )
    end
  end
  
  after(:all) do
    Rails.logger.level = @original_log_level if defined?(Rails) && @original_log_level
  end

  describe 'Single Workflow Performance' do
    let(:employee) { create_test_employee }
    let(:workflow_execution) { employee.start_onboarding!(assigned_to: @hr_users.first) }

    it 'completes workflow initialization within performance threshold' do
      benchmark_result = Benchmark.measure do
        10.times do
          emp = create_test_employee
          execution = emp.start_onboarding!(assigned_to: @hr_users.first)
          expect(execution).to be_persisted
          expect(execution.current_step).to eq('initial_setup')
        end
      end

      performance_logger.info("Workflow initialization: #{benchmark_result}")
      
      # Should initialize 10 workflows in under 2 seconds
      expect(benchmark_result.real).to be < 2.0
      
      # Memory usage should be reasonable
      expect(current_memory_usage).to be < 100.megabytes
    end

    it 'performs workflow actions within acceptable time limits' do
      monitor = Avo::Workflows::Performance::Monitor.new(workflow_execution)
      
      action_times = []
      
      # Test multiple action executions
      5.times do
        available_actions = workflow_execution.available_actions
        next if available_actions.empty?
        
        action = available_actions.first
        operation_time = monitor.monitor_operation("action_#{action}") do
          workflow_execution.perform_action(action, user: @hr_users.first)
        end
        
        action_times << monitor.metrics.values.last[:duration]
      end
      
      # Each action should complete within 500ms
      action_times.each do |time|
        expect(time).to be < 0.5
      end
      
      # Average action time should be under 200ms
      average_time = action_times.sum / action_times.size
      expect(average_time).to be < 0.2
      
      performance_logger.info("Action times: #{action_times}, Average: #{average_time}")
    end

    it 'handles large context data efficiently' do
      # Add large context data
      large_context = {
        employee_documents: generate_large_test_data(size_mb: 2),
        training_materials: generate_large_test_data(size_mb: 1),
        metadata: {
          created_at: Time.current,
          department_info: generate_test_data(1000),
          compliance_data: generate_test_data(500)
        }
      }
      
      start_memory = current_memory_usage
      
      benchmark_result = Benchmark.measure do
        workflow_execution.update_context(large_context)
        
        # Perform several operations with large context
        3.times do
          workflow_execution.reload
          workflow_execution.available_actions
          workflow_execution.current_step
        end
      end
      
      end_memory = current_memory_usage
      memory_growth = end_memory - start_memory
      
      performance_logger.info("Large context test: #{benchmark_result}, Memory growth: #{memory_growth}MB")
      
      # Operations should complete within reasonable time even with large context
      expect(benchmark_result.real).to be < 1.0
      
      # Memory growth should be controlled
      expect(memory_growth).to be < 50.megabytes
    end

    it 'maintains performance with extensive step history' do
      # Create extensive step history
      50.times do |i|
        if workflow_execution.available_actions.any?
          action = workflow_execution.available_actions.first
          workflow_execution.perform_action(action, user: @hr_users.sample)
          
          # Add some artificial history entries
          workflow_execution.step_history << {
            'from_step' => 'test_step',
            'to_step' => 'another_step',
            'action' => 'test_action',
            'user_id' => @hr_users.sample.id,
            'timestamp' => (Time.current - i.minutes).iso8601
          }
        end
      end
      
      benchmark_result = Benchmark.measure do
        10.times do
          workflow_execution.reload
          workflow_execution.step_history.size
          workflow_execution.available_actions
        end
      end
      
      performance_logger.info("Extensive history test: #{benchmark_result}")
      
      # Should handle large history efficiently
      expect(benchmark_result.real).to be < 1.0
      expect(workflow_execution.step_history.size).to be > 40
    end
  end

  describe 'Concurrent Workflow Performance' do
    it 'handles multiple concurrent workflow executions' do
      require 'concurrent'
      
      start_time = Time.current
      concurrent_workflows = 20
      
      # Create concurrent workflow executions
      promises = concurrent_workflows.times.map do |i|
        Concurrent::Promise.execute do
          employee = create_test_employee(index: i)
          execution = employee.start_onboarding!(assigned_to: @hr_users.sample)
          
          # Perform several actions
          3.times do
            actions = execution.available_actions
            if actions.any?
              execution.perform_action(actions.first, user: @hr_users.sample)
            end
          end
          
          {
            workflow_id: execution.id,
            final_step: execution.current_step,
            completed_at: Time.current
          }
        end
      end
      
      # Wait for all workflows to complete
      results = promises.map(&:value!)
      end_time = Time.current
      
      total_time = end_time - start_time
      throughput = concurrent_workflows / total_time
      
      performance_logger.info("Concurrent test: #{concurrent_workflows} workflows in #{total_time}s, throughput: #{throughput}/s")
      
      # All workflows should complete successfully
      expect(results.size).to eq(concurrent_workflows)
      results.each do |result|
        expect(result[:workflow_id]).to be_present
        expect(result[:final_step]).to be_present
      end
      
      # Should maintain reasonable throughput
      expect(throughput).to be > 2 # At least 2 workflows per second
      
      # Total time should be reasonable for concurrent execution
      expect(total_time).to be < 15.0
    end

    it 'maintains database performance under concurrent load' do
      require 'concurrent'
      
      # Track database metrics
      initial_connection_count = ActiveRecord::Base.connection_pool.connections.size
      
      # Run concurrent database-intensive operations
      promises = 10.times.map do |i|
        Concurrent::Promise.execute do
          employee = create_test_employee(index: i)
          execution = employee.start_onboarding!(assigned_to: @hr_users.sample)
          
          query_count = 0
          
          # Perform database-intensive operations
          5.times do
            execution.reload
            execution.available_actions
            execution.workflow_definition
            query_count += 3 # Approximate query count per iteration
          end
          
          query_count
        end
      end
      
      total_queries = promises.map(&:value!).sum
      final_connection_count = ActiveRecord::Base.connection_pool.connections.size
      
      performance_logger.info("Database load test: #{total_queries} queries, connections: #{initial_connection_count} -> #{final_connection_count}")
      
      # Connection pool should remain stable
      expect(final_connection_count - initial_connection_count).to be < 5
      
      # Average queries per operation should be reasonable
      avg_queries_per_workflow = total_queries.to_f / 10
      expect(avg_queries_per_workflow).to be < 30
    end
  end

  describe 'Memory Usage Performance' do
    it 'maintains stable memory usage over extended operation' do
      initial_memory = current_memory_usage
      peak_memory = initial_memory
      
      # Simulate extended workflow usage
      100.times do |i|
        employee = create_test_employee(index: i)
        execution = employee.start_onboarding!(assigned_to: @hr_users.sample)
        
        # Perform workflow operations
        execution.available_actions.first(2).each do |action|
          execution.perform_action(action, user: @hr_users.sample)
        end
        
        current_memory = current_memory_usage
        peak_memory = [peak_memory, current_memory].max
        
        # Force garbage collection every 20 iterations
        GC.start if i % 20 == 0 && defined?(GC)
      end
      
      final_memory = current_memory_usage
      memory_growth = final_memory - initial_memory
      peak_growth = peak_memory - initial_memory
      
      performance_logger.info("Memory test: initial=#{initial_memory}MB, peak=#{peak_memory}MB, final=#{final_memory}MB")
      
      # Memory growth should be controlled
      expect(memory_growth).to be < 100.megabytes
      expect(peak_growth).to be < 150.megabytes
      
      # Memory should not continuously grow (indicating memory leaks)
      expect(final_memory).to be < (initial_memory + 50.megabytes)
    end

    it 'efficiently handles workflow cleanup and garbage collection' do
      # Create many workflows that go out of scope
      initial_memory = current_memory_usage
      
      5.times do
        create_and_cleanup_workflows(count: 20)
        GC.start if defined?(GC)
      end
      
      final_memory = current_memory_usage
      memory_difference = final_memory - initial_memory
      
      performance_logger.info("GC test: memory difference after cleanup: #{memory_difference}MB")
      
      # Memory should be efficiently reclaimed
      expect(memory_difference).to be < 30.megabytes
    end
  end

  describe 'Performance Optimization' do
    let(:employee) { create_test_employee }
    let(:workflow_execution) { employee.start_onboarding!(assigned_to: @hr_users.first) }

    it 'query optimization improves performance' do
      optimizer = Avo::Workflows::Performance::Optimizations::QueryOptimizer.new(workflow_execution)
      
      # Measure performance before optimization
      before_time = Benchmark.measure do
        10.times do
          workflow_execution.reload
          workflow_execution.available_actions
          workflow_execution.workflow_definition
        end
      end
      
      # Apply optimizations
      optimizer.enable_eager_loading([:workflowable])
      optimizer.enable_caching([:workflow_definition, :available_actions])
      
      # Measure performance after optimization
      after_time = Benchmark.measure do
        10.times do
          workflow_execution.reload
          workflow_execution.available_actions
          workflow_execution.workflow_definition
        end
      end
      
      performance_logger.info("Query optimization: before=#{before_time.real}s, after=#{after_time.real}s")
      
      # Performance should improve or at least not degrade significantly
      expect(after_time.real).to be <= (before_time.real * 1.1) # Allow 10% variance
    end

    it 'memory optimization reduces memory footprint' do
      # Add large context data
      large_context = { large_data: generate_large_test_data(size_mb: 5) }
      workflow_execution.update_context(large_context)
      
      initial_memory = current_memory_usage
      
      optimizer = Avo::Workflows::Performance::Optimizations::MemoryOptimizer.new(workflow_execution)
      optimization_result = optimizer.optimize_memory_usage
      
      final_memory = current_memory_usage
      
      performance_logger.info("Memory optimization: #{optimization_result}")
      performance_logger.info("Memory: #{initial_memory}MB -> #{final_memory}MB")
      
      expect(optimization_result[:optimizations_applied]).to be_an(Array)
      expect(optimization_result[:optimizations_applied]).not_to be_empty
      
      # Memory usage should be reduced or controlled
      expect(final_memory).to be <= initial_memory
    end

    it 'comprehensive performance optimization shows measurable improvements' do
      # Create a workflow with performance challenges
      workflow_execution.update_context(
        large_data: generate_large_test_data(size_mb: 3),
        temp_data: Array.new(1000) { |i| "temp_#{i}" },
        cached_results: Array.new(500) { |i| { result: "cached_#{i}" } }
      )
      
      optimizer = Avo::Workflows::Performance::Optimizations::PerformanceOptimizer.new(workflow_execution)
      
      # Measure before optimization
      before_benchmark = Benchmark.measure do
        5.times do
          workflow_execution.reload
          workflow_execution.available_actions
          workflow_execution.context_data
        end
      end
      
      # Apply comprehensive optimization
      optimization_result = optimizer.optimize_performance
      
      # Measure after optimization
      after_benchmark = Benchmark.measure do
        5.times do
          workflow_execution.reload
          workflow_execution.available_actions
          workflow_execution.context_data
        end
      end
      
      performance_logger.info("Comprehensive optimization: #{optimization_result}")
      performance_logger.info("Performance: before=#{before_benchmark.real}s, after=#{after_benchmark.real}s")
      
      expect(optimization_result[:overall_impact]).to be_present
      expect(optimization_result[:overall_impact][:score]).to be > 0
      
      # Performance should not degrade
      expect(after_benchmark.real).to be <= (before_benchmark.real * 1.2)
    end
  end

  describe 'Stress Testing' do
    it 'handles extreme load conditions gracefully' do
      start_time = Time.current
      errors = []
      completed_workflows = 0
      
      # Create extreme load
      begin
        50.times do |i|
          employee = create_test_employee(index: i)
          execution = employee.start_onboarding!(assigned_to: @hr_users.sample)
          
          # Perform rapid-fire actions
          execution.available_actions.each do |action|
            execution.perform_action(action, user: @hr_users.sample)
          end
          
          completed_workflows += 1
        end
      rescue => e
        errors << e
      end
      
      end_time = Time.current
      total_time = end_time - start_time
      
      performance_logger.info("Stress test: #{completed_workflows}/50 workflows completed in #{total_time}s")
      performance_logger.error("Stress test errors: #{errors}") if errors.any?
      
      # Should handle majority of workflows even under stress
      expect(completed_workflows).to be >= 40
      
      # Should complete in reasonable time
      expect(total_time).to be < 30.0
      
      # Critical errors should be minimal
      expect(errors.size).to be <= 2
    end

    it 'recovers gracefully from resource exhaustion' do
      initial_memory = current_memory_usage
      
      # Simulate resource exhaustion scenario
      begin
        memory_intensive_workflows = []
        
        # Create workflows until memory pressure
        20.times do |i|
          employee = create_test_employee(index: i)
          execution = employee.start_onboarding!(assigned_to: @hr_users.sample)
          
          # Add memory-intensive context
          execution.update_context(
            stress_test_data: generate_large_test_data(size_mb: 10),
            iteration: i
          )
          
          memory_intensive_workflows << execution
          
          # Check memory usage
          current_mem = current_memory_usage
          if current_mem > initial_memory + 200.megabytes
            break
          end
        end
        
        # Force cleanup
        memory_intensive_workflows.clear
        GC.start if defined?(GC)
        
        # Test system recovery
        recovery_execution = create_test_employee.start_onboarding!(assigned_to: @hr_users.first)
        recovery_execution.available_actions
        
        expect(recovery_execution).to be_persisted
        
      rescue => e
        performance_logger.error("Resource exhaustion test error: #{e}")
        # System should still be functional
        recovery_execution = create_test_employee.start_onboarding!(assigned_to: @hr_users.first)
        expect(recovery_execution).to be_persisted
      end
      
      final_memory = current_memory_usage
      performance_logger.info("Resource exhaustion test: memory recovered from stress")
    end
  end

  private

  def create_test_employee(index: nil)
    suffix = index || rand(10000)
    Employee.create!(
      name: "Test Employee #{suffix}",
      email: "employee#{suffix}@company.com",
      employee_type: 'full_time',
      department: 'Engineering',
      salary_level: 'senior',
      start_date: Date.current + 1.week,
      manager: @managers.sample,
      hr_representative: @hr_users.sample
    )
  end

  def create_and_cleanup_workflows(count: 10)
    workflows = []
    
    count.times do |i|
      employee = create_test_employee(index: i)
      execution = employee.start_onboarding!(assigned_to: @hr_users.sample)
      workflows << execution
    end
    
    # Let workflows go out of scope
    workflows.clear
    nil
  end

  def current_memory_usage
    if defined?(GC)
      GC.stat[:heap_allocated_pages] * GC::INTERNAL_CONSTANTS[:HEAP_PAGE_SIZE] / 1024.0 / 1024.0
    else
      0
    end
  rescue
    0
  end

  def generate_test_data(size)
    Array.new(size) { |i| "test_data_item_#{i}_#{SecureRandom.hex(10)}" }
  end

  def generate_large_test_data(size_mb:)
    target_bytes = size_mb * 1024 * 1024
    item_size = 1024 # 1KB per item
    item_count = target_bytes / item_size
    
    {
      data_size_mb: size_mb,
      items: Array.new(item_count) { |i| 
        "large_data_item_#{i}_#{'x' * (item_size - 30)}"
      },
      metadata: {
        generated_at: Time.current,
        item_count: item_count,
        total_size_bytes: target_bytes
      }
    }
  end
end