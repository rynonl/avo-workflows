# frozen_string_literal: true

module Avo
  module Workflows
    # Performance monitoring and optimization utilities for workflow systems
    #
    # Provides comprehensive performance analysis, benchmarking, and optimization
    # tools for workflow execution, database queries, and memory usage.
    #
    # @example Basic performance monitoring
    #   monitor = Avo::Workflows::Performance::Monitor.new(workflow_execution)
    #   report = monitor.performance_report
    #   puts report[:execution_time]
    #
    # @example Benchmarking workflow operations
    #   benchmark = Avo::Workflows::Performance::Benchmark.new
    #   benchmark.compare_workflows([workflow1, workflow2]) do |w|
    #     w.perform_action(:next_step, user: user)
    #   end
    module Performance
      # Performance monitoring for individual workflow executions
      class Monitor
        attr_reader :workflow_execution, :start_time, :metrics

        def initialize(workflow_execution)
          @workflow_execution = workflow_execution
          @start_time = Time.current
          @metrics = {}
          @memory_snapshots = []
          @query_logs = []
        end

        # Generate comprehensive performance report
        #
        # @return [Hash] performance metrics and analysis
        def performance_report
          {
            execution_summary: execution_summary,
            timing_analysis: timing_analysis,
            memory_analysis: memory_analysis,
            database_analysis: database_analysis,
            bottleneck_analysis: bottleneck_analysis,
            optimization_recommendations: optimization_recommendations
          }
        end

        # Start performance monitoring for an operation
        #
        # @param operation_name [String] name of the operation being monitored
        # @return [String] operation ID for tracking
        def start_operation(operation_name)
          operation_id = SecureRandom.uuid
          
          @metrics[operation_id] = {
            name: operation_name,
            start_time: Time.current,
            start_memory: current_memory_usage,
            queries_before: query_count
          }
          
          take_memory_snapshot(operation_name, :start)
          operation_id
        end

        # End performance monitoring for an operation
        #
        # @param operation_id [String] operation ID from start_operation
        # @return [Hash] operation performance metrics
        def end_operation(operation_id)
          return nil unless @metrics[operation_id]

          operation = @metrics[operation_id]
          end_time = Time.current
          end_memory = current_memory_usage
          
          operation.merge!({
            end_time: end_time,
            duration: end_time - operation[:start_time],
            end_memory: end_memory,
            memory_delta: end_memory - operation[:start_memory],
            query_count: query_count - operation[:queries_before]
          })
          
          take_memory_snapshot(operation[:name], :end)
          operation
        end

        # Monitor a block of code for performance
        #
        # @param operation_name [String] name of the operation
        # @yield block to monitor
        # @return [Object] result of the block
        def monitor_operation(operation_name)
          operation_id = start_operation(operation_name)
          result = yield
          metrics = end_operation(operation_id)
          
          Rails.logger.info("Performance: #{operation_name} took #{metrics[:duration]}s, #{metrics[:memory_delta]}MB memory, #{metrics[:query_count]} queries") if defined?(Rails)
          
          result
        end

        # Analyze workflow execution performance over time
        #
        # @return [Hash] performance trends and patterns
        def analyze_execution_trends
          history = workflow_execution.step_history || []
          
          {
            step_durations: calculate_step_durations(history),
            peak_memory_steps: identify_memory_peaks,
            query_intensive_steps: identify_query_hotspots,
            performance_trends: calculate_performance_trends
          }
        end

        # Generate performance recommendations
        #
        # @return [Array<Hash>] optimization recommendations
        def optimization_recommendations
          recommendations = []
          
          # Memory usage recommendations
          if peak_memory_usage > 100.megabytes
            recommendations << {
              type: :memory,
              severity: :high,
              message: "High memory usage detected (#{format_memory(peak_memory_usage)})",
              suggestion: "Consider implementing data streaming or pagination for large datasets"
            }
          end
          
          # Query count recommendations
          if total_query_count > 50
            recommendations << {
              type: :database,
              severity: :medium,
              message: "High query count (#{total_query_count} queries)",
              suggestion: "Implement eager loading or query optimization"
            }
          end
          
          # Execution time recommendations
          if total_execution_time > 30.seconds
            recommendations << {
              type: :performance,
              severity: :medium,
              message: "Long execution time (#{total_execution_time}s)",
              suggestion: "Consider breaking workflow into smaller steps or implementing async processing"
            }
          end
          
          recommendations
        end

        # Export performance data for external analysis
        #
        # @param format [Symbol] export format (:json, :csv, :yaml)
        # @return [String] exported data
        def export_performance_data(format: :json)
          data = {
            workflow_execution_id: workflow_execution.id,
            workflow_class: workflow_execution.workflow_class,
            performance_report: performance_report,
            metrics: @metrics,
            memory_snapshots: @memory_snapshots,
            exported_at: Time.current.iso8601
          }

          case format
          when :json
            JSON.pretty_generate(data)
          when :yaml
            YAML.dump(data)
          when :csv
            export_to_csv(data)
          else
            data
          end
        end

        private

        def execution_summary
          {
            workflow_id: workflow_execution.id,
            workflow_class: workflow_execution.workflow_class,
            current_step: workflow_execution.current_step,
            total_steps: workflow_execution.step_history&.length || 0,
            monitoring_duration: Time.current - start_time
          }
        end

        def timing_analysis
          {
            total_execution_time: total_execution_time,
            average_operation_time: average_operation_time,
            slowest_operations: slowest_operations,
            fastest_operations: fastest_operations
          }
        end

        def memory_analysis
          {
            current_memory: current_memory_usage,
            peak_memory: peak_memory_usage,
            memory_growth: memory_growth_rate,
            memory_snapshots: @memory_snapshots.last(10)
          }
        end

        def database_analysis
          {
            total_queries: total_query_count,
            queries_per_operation: queries_per_operation,
            query_hotspots: query_hotspots
          }
        end

        def bottleneck_analysis
          operations = @metrics.values.sort_by { |op| op[:duration] || 0 }.reverse
          
          {
            time_bottlenecks: operations.first(3),
            memory_bottlenecks: operations.sort_by { |op| op[:memory_delta] || 0 }.reverse.first(3),
            query_bottlenecks: operations.sort_by { |op| op[:query_count] || 0 }.reverse.first(3)
          }
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

        def query_count
          if defined?(ActiveRecord)
            ActiveRecord::Base.connection.query_cache.size
          else
            0
          end
        rescue
          0
        end

        def take_memory_snapshot(operation, phase)
          @memory_snapshots << {
            operation: operation,
            phase: phase,
            timestamp: Time.current,
            memory_usage: current_memory_usage,
            gc_stats: gc_statistics
          }
        end

        def gc_statistics
          return {} unless defined?(GC)
          
          {
            count: GC.count,
            heap_allocated_pages: GC.stat[:heap_allocated_pages],
            heap_free_slots: GC.stat[:heap_free_slots],
            total_allocated_objects: GC.stat[:total_allocated_objects]
          }
        rescue
          {}
        end

        def total_execution_time
          @metrics.values.sum { |op| op[:duration] || 0 }
        end

        def average_operation_time
          return 0 if @metrics.empty?
          total_execution_time / @metrics.size
        end

        def slowest_operations
          @metrics.values
                  .select { |op| op[:duration] }
                  .sort_by { |op| op[:duration] }
                  .reverse
                  .first(5)
        end

        def fastest_operations
          @metrics.values
                  .select { |op| op[:duration] }
                  .sort_by { |op| op[:duration] }
                  .first(5)
        end

        def peak_memory_usage
          @memory_snapshots.map { |snapshot| snapshot[:memory_usage] }.max || 0
        end

        def memory_growth_rate
          return 0 if @memory_snapshots.size < 2
          
          first = @memory_snapshots.first[:memory_usage]
          last = @memory_snapshots.last[:memory_usage]
          (last - first) / @memory_snapshots.size
        end

        def total_query_count
          @metrics.values.sum { |op| op[:query_count] || 0 }
        end

        def queries_per_operation
          return 0 if @metrics.empty?
          total_query_count.to_f / @metrics.size
        end

        def query_hotspots
          @metrics.values
                  .select { |op| op[:query_count] && op[:query_count] > 5 }
                  .sort_by { |op| op[:query_count] }
                  .reverse
        end

        def calculate_step_durations(history)
          durations = []
          
          history.each_cons(2) do |current, next_step|
            if current['timestamp'] && next_step['timestamp']
              duration = Time.parse(next_step['timestamp']) - Time.parse(current['timestamp'])
              durations << {
                from_step: current['to_step'],
                to_step: next_step['to_step'], 
                duration: duration
              }
            end
          end
          
          durations
        rescue
          []
        end

        def identify_memory_peaks
          @memory_snapshots
            .select { |snapshot| snapshot[:memory_usage] > average_memory_usage * 1.5 }
            .map { |snapshot| { operation: snapshot[:operation], memory: snapshot[:memory_usage] } }
        end

        def identify_query_hotspots
          @metrics.values
                  .select { |op| op[:query_count] && op[:query_count] > queries_per_operation * 2 }
                  .map { |op| { operation: op[:name], queries: op[:query_count] } }
        end

        def calculate_performance_trends
          return {} if @memory_snapshots.size < 3
          
          {
            memory_trend: calculate_trend(@memory_snapshots.map { |s| s[:memory_usage] }),
            operation_time_trend: calculate_trend(@metrics.values.map { |op| op[:duration] }.compact)
          }
        end

        def calculate_trend(data)
          return :stable if data.size < 3
          
          recent_avg = data.last(3).sum / 3.0
          early_avg = data.first(3).sum / 3.0
          
          if recent_avg > early_avg * 1.2
            :increasing
          elsif recent_avg < early_avg * 0.8
            :decreasing
          else
            :stable
          end
        end

        def average_memory_usage
          return 0 if @memory_snapshots.empty?
          @memory_snapshots.sum { |s| s[:memory_usage] } / @memory_snapshots.size
        end

        def format_memory(bytes)
          "#{(bytes / 1024.0 / 1024.0).round(2)}MB"
        end

        def export_to_csv(data)
          begin
            require 'csv'
          rescue LoadError
            return "CSV export requires 'csv' gem to be available"
          end
          
          CSV.generate do |csv|
            csv << ['Operation', 'Duration', 'Memory Delta', 'Query Count']
            
            data[:metrics].each do |_, metric|
              csv << [
                metric[:name],
                metric[:duration],
                metric[:memory_delta],
                metric[:query_count]
              ]
            end
          end
        end
      end

      # Benchmarking utilities for comparing workflow performance
      class Benchmark
        attr_reader :results

        def initialize
          @results = {}
        end

        # Compare multiple workflows or operations
        #
        # @param subjects [Array] workflows or operations to compare
        # @param iterations [Integer] number of iterations per subject
        # @yield [subject] block to execute for each subject
        # @return [Hash] comparison results
        def compare(subjects, iterations: 1)
          @results = {}
          
          subjects.each do |subject|
            @results[subject_key(subject)] = benchmark_subject(subject, iterations) do
              yield(subject)
            end
          end
          
          generate_comparison_report
        end

        # Benchmark a single operation multiple times
        #
        # @param operation_name [String] name of the operation
        # @param iterations [Integer] number of iterations
        # @yield block to benchmark
        # @return [Hash] benchmark results
        def benchmark_operation(operation_name, iterations: 10)
          times = []
          memory_usage = []
          
          iterations.times do
            gc_before = GC.stat if defined?(GC)
            memory_before = current_memory_usage
            start_time = Time.current
            
            yield
            
            end_time = Time.current
            memory_after = current_memory_usage
            
            times << (end_time - start_time)
            memory_usage << (memory_after - memory_before)
          end
          
          {
            operation: operation_name,
            iterations: iterations,
            times: {
              min: times.min,
              max: times.max,
              average: times.sum / times.size,
              median: calculate_median(times)
            },
            memory: {
              min: memory_usage.min,
              max: memory_usage.max,
              average: memory_usage.sum / memory_usage.size,
              median: calculate_median(memory_usage)
            }
          }
        end

        # Load test workflow operations
        #
        # @param workflow_class [Class] workflow class to test
        # @param concurrent_executions [Integer] number of concurrent executions
        # @param operations_per_execution [Integer] operations per execution
        # @return [Hash] load test results
        def load_test(workflow_class, concurrent_executions: 10, operations_per_execution: 5)
          require 'concurrent'
          
          start_time = Time.current
          promises = []
          
          concurrent_executions.times do |i|
            promises << Concurrent::Promise.execute do
              load_test_single_execution(workflow_class, operations_per_execution, i)
            end
          end
          
          results = promises.map(&:value!)
          end_time = Time.current
          
          {
            total_time: end_time - start_time,
            concurrent_executions: concurrent_executions,
            operations_per_execution: operations_per_execution,
            total_operations: concurrent_executions * operations_per_execution,
            execution_results: results,
            throughput: (concurrent_executions * operations_per_execution) / (end_time - start_time),
            memory_peak: results.map { |r| r[:peak_memory] }.max,
            average_execution_time: results.map { |r| r[:total_time] }.sum / results.size
          }
        end

        # Memory stress test for workflows
        #
        # @param workflow_execution [WorkflowExecution] execution to test
        # @param data_size_mb [Integer] size of test data in megabytes
        # @return [Hash] stress test results
        def memory_stress_test(workflow_execution, data_size_mb: 10)
          initial_memory = current_memory_usage
          test_data = generate_test_data(data_size_mb)
          
          start_time = Time.current
          
          # Add test data to workflow context
          workflow_execution.update_context!(stress_test_data: test_data)
          
          # Perform multiple operations
          operations_completed = 0
          peak_memory = initial_memory
          
          10.times do
            current_mem = current_memory_usage
            peak_memory = [peak_memory, current_mem].max
            
            # Simulate workflow operations
            workflow_execution.available_actions.each do |action|
              operations_completed += 1
              break if current_memory_usage > initial_memory + (data_size_mb * 2)
            end
          end
          
          end_time = Time.current
          final_memory = current_memory_usage
          
          {
            test_duration: end_time - start_time,
            operations_completed: operations_completed,
            initial_memory: initial_memory,
            peak_memory: peak_memory,
            final_memory: final_memory,
            memory_growth: final_memory - initial_memory,
            memory_efficiency: operations_completed.to_f / (peak_memory - initial_memory + 1)
          }
        end

        private

        def benchmark_subject(subject, iterations)
          times = []
          memory_deltas = []
          
          iterations.times do
            memory_before = current_memory_usage
            start_time = Time.current
            
            yield
            
            end_time = Time.current
            memory_after = current_memory_usage
            
            times << (end_time - start_time)
            memory_deltas << (memory_after - memory_before)
          end
          
          {
            times: times,
            memory_deltas: memory_deltas,
            average_time: times.sum / times.size,
            average_memory: memory_deltas.sum / memory_deltas.size
          }
        end

        def generate_comparison_report
          return {} if @results.empty?
          
          fastest = @results.min_by { |_, data| data[:average_time] }
          slowest = @results.max_by { |_, data| data[:average_time] }
          most_memory_efficient = @results.min_by { |_, data| data[:average_memory] }
          
          {
            summary: {
              fastest: { subject: fastest[0], time: fastest[1][:average_time] },
              slowest: { subject: slowest[0], time: slowest[1][:average_time] },
              most_memory_efficient: { 
                subject: most_memory_efficient[0], 
                memory: most_memory_efficient[1][:average_memory] 
              }
            },
            detailed_results: @results,
            performance_ratios: calculate_performance_ratios
          }
        end

        def calculate_performance_ratios
          base_time = @results.values.first[:average_time]
          base_memory = @results.values.first[:average_memory]
          
          @results.transform_values do |data|
            {
              time_ratio: data[:average_time] / base_time,
              memory_ratio: data[:average_memory] / (base_memory == 0 ? 1 : base_memory)
            }
          end
        end

        def load_test_single_execution(workflow_class, operations_count, execution_id)
          start_time = Time.current
          initial_memory = current_memory_usage
          peak_memory = initial_memory
          
          # Create a test workflowable
          workflowable = create_test_workflowable_for_class(workflow_class)
          execution = workflowable.start_workflow!(workflow_class.name)
          
          operations_count.times do |i|
            current_memory = current_memory_usage
            peak_memory = [peak_memory, current_memory].max
            
            available_actions = execution.available_actions
            if available_actions.any?
              execution.perform_action(available_actions.first, user: create_test_user)
            end
          end
          
          end_time = Time.current
          
          {
            execution_id: execution_id,
            total_time: end_time - start_time,
            operations_completed: operations_count,
            initial_memory: initial_memory,
            peak_memory: peak_memory,
            final_memory: current_memory_usage,
            workflow_execution_id: execution.id
          }
        rescue => e
          {
            execution_id: execution_id,
            error: e.message,
            total_time: Time.current - start_time
          }
        end

        def subject_key(subject)
          case subject
          when String, Symbol
            subject.to_s
          when Class
            subject.name
          else
            subject.class.name
          end
        end

        def calculate_median(array)
          sorted = array.sort
          size = sorted.size
          
          if size.even?
            (sorted[size / 2 - 1] + sorted[size / 2]) / 2.0
          else
            sorted[size / 2]
          end
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

        def generate_test_data(size_mb)
          data_size = size_mb * 1024 * 1024
          chunk_size = 1024
          chunks = data_size / chunk_size
          
          {
            chunks: chunks.times.map { |i| "test_data_chunk_#{i}_#{'x' * (chunk_size - 20)}" },
            metadata: {
              size_mb: size_mb,
              generated_at: Time.current,
              chunk_count: chunks
            }
          }
        end

        def create_test_workflowable_for_class(workflow_class)
          # This would need to be customized based on the actual workflowable types
          case workflow_class.name
          when 'EmployeeOnboardingWorkflow'
            User.create!(name: "Test User #{SecureRandom.uuid}", email: "test-#{SecureRandom.uuid}@example.com")
          when 'BlogPostWorkflow'
            # Assuming BlogPost model exists
            BlogPost.create!(title: "Test Post #{SecureRandom.uuid}", content: "Test content")
          else
            # Generic fallback - create a simple test object
            OpenStruct.new(id: SecureRandom.uuid, test_attribute: "test_value")
          end
        rescue
          OpenStruct.new(id: SecureRandom.uuid, test_attribute: "test_value")
        end

        def create_test_user
          User.new(id: 1, name: "Test User", email: "test@example.com")
        rescue
          OpenStruct.new(id: 1, name: "Test User", email: "test@example.com")
        end
      end

      # Class methods for easy access to performance tools
      def self.monitor(workflow_execution)
        Monitor.new(workflow_execution)
      end

      def self.benchmark
        Benchmark.new
      end

      # Quick performance check for a workflow execution
      #
      # @param workflow_execution [WorkflowExecution] execution to analyze
      # @return [Hash] performance summary
      def self.quick_analysis(workflow_execution)
        monitor = Monitor.new(workflow_execution)
        report = monitor.performance_report
        
        {
          performance_score: calculate_performance_score(report),
          key_metrics: {
            memory_usage: report[:memory_analysis][:current_memory],
            execution_time: report[:timing_analysis][:total_execution_time],
            query_efficiency: report[:database_analysis][:total_queries]
          },
          recommendations: monitor.optimization_recommendations.first(3)
        }
      end

      private

      def self.calculate_performance_score(report)
        # Simple scoring algorithm (0-100)
        score = 100
        
        # Deduct points for high memory usage
        memory_mb = report[:memory_analysis][:current_memory]
        score -= (memory_mb / 10).to_i if memory_mb > 50
        
        # Deduct points for slow execution
        exec_time = report[:timing_analysis][:total_execution_time]
        score -= (exec_time * 2).to_i if exec_time > 5
        
        # Deduct points for many queries
        query_count = report[:database_analysis][:total_queries]
        score -= (query_count / 5).to_i if query_count > 20
        
        [score, 0].max
      end
    end
  end
end