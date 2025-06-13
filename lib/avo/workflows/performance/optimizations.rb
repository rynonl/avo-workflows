# frozen_string_literal: true

module Avo
  module Workflows
    module Performance
      # Performance optimization utilities and automatic improvements
      #
      # Provides tools for automatically optimizing workflow performance,
      # including database query optimization, memory management, and
      # execution path optimization.
      module Optimizations
        # Database query optimization for workflow operations
        class QueryOptimizer
          attr_reader :workflow_execution

          def initialize(workflow_execution)
            @workflow_execution = workflow_execution
            @query_cache = {}
            @eager_load_associations = []
          end

          # Optimize database queries for workflow operations
          #
          # @param operation [Symbol] operation to optimize
          # @return [Hash] optimization results
          def optimize_queries_for_operation(operation)
            original_queries = query_count
            
            case operation
            when :step_history_analysis
              optimize_step_history_queries
            when :context_operations
              optimize_context_queries  
            when :validation_checks
              optimize_validation_queries
            when :action_availability
              optimize_action_queries
            else
              optimize_general_queries
            end
            
            optimized_queries = query_count
            
            {
              operation: operation,
              queries_before: original_queries,
              queries_after: optimized_queries,
              queries_saved: original_queries - optimized_queries,
              optimizations_applied: @optimizations_applied || []
            }
          end

          # Enable eager loading for related associations
          #
          # @param associations [Array<Symbol>] associations to eager load
          def enable_eager_loading(associations)
            @eager_load_associations.concat(associations)
            @optimizations_applied ||= []
            @optimizations_applied << "eager_loading: #{associations.join(', ')}"
          end

          # Cache frequently accessed workflow data
          #
          # @param cache_keys [Array<Symbol>] data types to cache
          def enable_caching(cache_keys)
            cache_keys.each do |key|
              case key
              when :workflow_definition
                cache_workflow_definition
              when :step_definitions
                cache_step_definitions
              when :available_actions
                cache_available_actions
              when :context_data
                cache_context_data
              end
            end
            
            @optimizations_applied ||= []
            @optimizations_applied << "caching: #{cache_keys.join(', ')}"
          end

          # Optimize context data storage and retrieval
          def optimize_context_storage
            context = workflow_execution.context_data || {}
            
            # Identify large objects that could be stored separately
            large_objects = find_large_context_objects(context)
            
            if large_objects.any?
              # Move large objects to separate storage
              optimized_context = extract_large_objects(context, large_objects)
              workflow_execution.update_column(:context_data, optimized_context)
              
              @optimizations_applied ||= []
              @optimizations_applied << "context_optimization: extracted #{large_objects.size} large objects"
            end
            
            large_objects
          end

          # Batch multiple workflow operations to reduce query overhead
          #
          # @param operations [Array<Proc>] operations to batch
          # @return [Array] results of all operations
          def batch_operations(operations)
            results = []
            
            ActiveRecord::Base.transaction do
              # Enable query caching for the batch
              original_cache = ActiveRecord::Base.connection.query_cache_enabled
              ActiveRecord::Base.connection.enable_query_cache!
              
              operations.each do |operation|
                results << operation.call
              end
              
              ActiveRecord::Base.connection.disable_query_cache! unless original_cache
            end
            
            results
          end

          # Generate query optimization report
          #
          # @return [Hash] detailed optimization analysis
          def optimization_report
            {
              current_queries: analyze_current_queries,
              optimization_opportunities: identify_optimization_opportunities,
              recommended_indexes: recommend_database_indexes,
              caching_opportunities: identify_caching_opportunities,
              eager_loading_suggestions: suggest_eager_loading
            }
          end

          private

          def optimize_step_history_queries
            # Eager load step history with proper ordering
            # Note: In practice this would eager load related associations
            enable_caching([:step_definitions])
          end

          def optimize_context_queries
            # Cache context data to avoid repeated JSON parsing
            enable_caching([:context_data])
            
            # Optimize large context updates
            optimize_context_storage
          end

          def optimize_validation_queries
            # Batch validation queries
            enable_eager_loading([:workflowable])
            enable_caching([:workflow_definition, :step_definitions])
          end

          def optimize_action_queries
            # Cache action definitions and conditions
            enable_caching([:available_actions, :workflow_definition])
          end

          def optimize_general_queries
            # Apply general optimizations
            enable_eager_loading([:workflowable])
            enable_caching([:workflow_definition])
          end

          def cache_workflow_definition
            @query_cache[:workflow_definition] ||= workflow_execution.workflow_definition
          end

          def cache_step_definitions
            @query_cache[:step_definitions] ||= begin
              workflow_def = cache_workflow_definition
              workflow_def.class.step_names.map { |name| workflow_def.class.find_step(name) }
            end
          end

          def cache_available_actions
            @query_cache[:available_actions] ||= workflow_execution.available_actions
          end

          def cache_context_data
            @query_cache[:context_data] ||= workflow_execution.context_data
          end

          def find_large_context_objects(context, threshold_kb = 10)
            large_objects = []
            
            context.each do |key, value|
              size_kb = value.to_s.bytesize / 1024.0
              if size_kb > threshold_kb
                large_objects << { key: key.to_sym, size_kb: size_kb, type: value.class.name }
              end
            end
            
            large_objects
          end

          def extract_large_objects(context, large_objects)
            optimized_context = context.dup
            
            large_objects.each do |obj_info|
              key = obj_info[:key]
              # Store reference instead of full object
              optimized_context[key] = {
                _type: 'large_object_reference',
                _key: key,
                _size: obj_info[:size_kb],
                _summary: context[key].to_s[0..100] + '...'
              }
            end
            
            optimized_context
          end

          def analyze_current_queries
            # This would integrate with ActiveRecord query logging
            {
              total_queries: query_count,
              slow_queries: identify_slow_queries,
              repeated_queries: identify_repeated_queries,
              n_plus_one_queries: identify_n_plus_one_queries
            }
          end

          def identify_optimization_opportunities
            opportunities = []
            
            # Check for N+1 queries
            if has_n_plus_one_queries?
              opportunities << {
                type: :n_plus_one,
                severity: :high,
                description: 'N+1 queries detected in workflow operations',
                solution: 'Implement eager loading for associations'
              }
            end
            
            # Check for repeated queries
            repeated = identify_repeated_queries
            if repeated.any?
              opportunities << {
                type: :repeated_queries,
                severity: :medium,
                description: "#{repeated.size} repeated queries found",
                solution: 'Enable query caching or optimize query logic'
              }
            end
            
            # Check for large context operations
            if large_context_detected?
              opportunities << {
                type: :large_context,
                severity: :medium,
                description: 'Large context data detected',
                solution: 'Implement context data optimization and external storage'
              }
            end
            
            opportunities
          end

          def recommend_database_indexes
            indexes = []
            
            # Recommend index on workflow_execution fields
            indexes << {
              table: 'avo_workflow_executions',
              columns: ['workflowable_type', 'workflowable_id'],
              reason: 'Optimize workflowable lookups'
            }
            
            indexes << {
              table: 'avo_workflow_executions', 
              columns: ['workflow_class', 'current_step'],
              reason: 'Optimize workflow status queries'
            }
            
            indexes << {
              table: 'avo_workflow_executions',
              columns: ['created_at'],
              reason: 'Optimize chronological queries'
            }
            
            indexes
          end

          def identify_caching_opportunities
            opportunities = []
            
            # Workflow definition caching
            opportunities << {
              type: :workflow_definition,
              benefit: :high,
              description: 'Cache workflow class definitions',
              implementation: 'Redis or in-memory caching'
            }
            
            # Step definition caching
            opportunities << {
              type: :step_definitions,
              benefit: :medium,
              description: 'Cache step definitions and validations',
              implementation: 'Application-level caching'
            }
            
            # Context data caching
            if context_access_frequency > 5
              opportunities << {
                type: :context_data,
                benefit: :medium,
                description: 'Cache frequently accessed context data',
                implementation: 'JSON parsing cache'
              }
            end
            
            opportunities
          end

          def suggest_eager_loading
            suggestions = []
            
            # Workflowable association
            suggestions << {
              association: :workflowable,
              benefit: :high,
              usage_pattern: 'Accessed in most workflow operations'
            }
            
            # User associations (if applicable)
            if workflow_uses_user_data?
              suggestions << {
                association: :user,
                benefit: :medium,
                usage_pattern: 'User data accessed during actions'
              }
            end
            
            suggestions
          end

          def query_count
            if defined?(ActiveRecord)
              # This is a simplified version - in practice you'd use tools like
              # query_trace, bullet, or custom query counting
              ActiveRecord::Base.connection.query_cache.size
            else
              0
            end
          rescue
            0
          end

          def identify_slow_queries
            # In practice, this would integrate with database query logs
            # or ActiveRecord query instrumentation
            []
          end

          def identify_repeated_queries
            # Track and identify repeated SQL queries
            []
          end

          def identify_n_plus_one_queries
            # Detect N+1 query patterns
            []
          end

          def has_n_plus_one_queries?
            # Simple detection logic - in practice this would be more sophisticated
            query_count > 10
          end

          def large_context_detected?
            context_size = workflow_execution.context_data&.to_s&.bytesize || 0
            context_size > 50.kilobytes
          end

          def context_access_frequency
            # Track how often context is accessed - simplified version
            5
          end

          def workflow_uses_user_data?
            # Check if workflow commonly accesses user data
            workflow_execution.context_data&.key?('user_id') || 
            workflow_execution.context_data&.key?('assigned_to')
          end
        end

        # Memory optimization for workflow executions
        class MemoryOptimizer
          attr_reader :workflow_execution

          def initialize(workflow_execution)
            @workflow_execution = workflow_execution
            @optimization_log = []
          end

          # Optimize memory usage for workflow execution
          #
          # @return [Hash] optimization results
          def optimize_memory_usage
            initial_memory = current_memory_usage
            
            optimizations = [
              optimize_context_storage,
              optimize_step_history,
              cleanup_temporary_data,
              optimize_object_references
            ]
            
            final_memory = current_memory_usage
            
            {
              initial_memory: initial_memory,
              final_memory: final_memory,
              memory_saved: initial_memory - final_memory,
              optimizations_applied: optimizations.compact,
              recommendations: generate_memory_recommendations
            }
          end

          # Clean up unused objects and references
          def cleanup_memory
            cleaned_objects = 0
            
            # Clean up instance variables that are no longer needed
            instance_variables.each do |var|
              if var.to_s.include?('temp_') || var.to_s.include?('cache_')
                remove_instance_variable(var)
                cleaned_objects += 1
              end
            end
            
            # Force garbage collection
            GC.start if defined?(GC)
            
            @optimization_log << "Cleaned #{cleaned_objects} temporary objects"
            cleaned_objects
          end

          # Optimize context data storage
          def optimize_context_storage
            return nil unless workflow_execution.context_data

            original_size = workflow_execution.context_data.to_s.bytesize
            
            # Remove redundant data
            optimized_context = remove_redundant_context_data
            
            # Compress large strings
            optimized_context = compress_large_context_values(optimized_context)
            
            # Update the workflow execution
            workflow_execution.update_column(:context_data, optimized_context)
            
            new_size = optimized_context.to_s.bytesize
            bytes_saved = original_size - new_size
            
            @optimization_log << "Context optimization saved #{bytes_saved} bytes"
            
            {
              type: :context_optimization,
              bytes_saved: bytes_saved,
              compression_ratio: (bytes_saved.to_f / original_size * 100).round(2)
            }
          end

          # Optimize step history storage
          def optimize_step_history
            return nil unless workflow_execution.step_history

            original_history = workflow_execution.step_history
            optimized_history = compress_step_history(original_history)
            
            if optimized_history.to_s.bytesize < original_history.to_s.bytesize
              workflow_execution.update_column(:step_history, optimized_history)
              
              bytes_saved = original_history.to_s.bytesize - optimized_history.to_s.bytesize
              @optimization_log << "Step history optimization saved #{bytes_saved} bytes"
              
              {
                type: :step_history_optimization,
                bytes_saved: bytes_saved,
                steps_optimized: original_history.size
              }
            end
          end

          # Clean up temporary data and caches
          def cleanup_temporary_data
            cleaned_data = []
            context = workflow_execution.context_data || {}
            
            # Remove temporary keys
            temp_keys = context.keys.select { |key| key.to_s.start_with?('temp_', 'cache_', '_tmp_') }
            temp_keys.each do |key|
              context.delete(key)
              cleaned_data << key
            end
            
            # Remove expired data
            expired_keys = find_expired_context_keys(context)
            expired_keys.each do |key|
              context.delete(key)
              cleaned_data << key
            end
            
            if cleaned_data.any?
              workflow_execution.update_column(:context_data, context)
              @optimization_log << "Cleaned #{cleaned_data.size} temporary/expired context keys"
              
              {
                type: :temporary_cleanup,
                keys_removed: cleaned_data.size,
                keys: cleaned_data
              }
            end
          end

          # Optimize object references to reduce memory footprint
          def optimize_object_references
            context = workflow_execution.context_data || {}
            optimizations = []
            
            # Convert full ActiveRecord objects to lightweight references
            context.each do |key, value|
              if value.is_a?(Hash) && value['class']&.include?('ActiveRecord')
                # Replace with lightweight reference
                context[key] = {
                  '_ref' => true,
                  'class' => value['class'],
                  'id' => value['id'],
                  'type' => 'active_record_reference'
                }
                optimizations << key
              end
            end
            
            if optimizations.any?
              workflow_execution.update_column(:context_data, context)
              @optimization_log << "Optimized #{optimizations.size} object references"
              
              {
                type: :reference_optimization,
                objects_optimized: optimizations.size,
                keys: optimizations
              }
            end
          end

          # Generate memory optimization recommendations
          def generate_memory_recommendations
            recommendations = []
            context_size = workflow_execution.context_data&.to_s&.bytesize || 0
            
            # Large context recommendation
            if context_size > 100.kilobytes
              recommendations << {
                type: :large_context,
                severity: :high,
                message: "Context data is #{(context_size / 1024.0).round(2)}KB",
                suggestion: "Consider storing large data externally (Redis, files, etc.)"
              }
            end
            
            # Step history recommendation
            history_size = workflow_execution.step_history&.to_s&.bytesize || 0
            if history_size > 50.kilobytes
              recommendations << {
                type: :large_history,
                severity: :medium,
                message: "Step history is #{(history_size / 1024.0).round(2)}KB",
                suggestion: "Implement history archiving or compression"
              }
            end
            
            # Memory usage trend recommendation
            if memory_usage_trending_up?
              recommendations << {
                type: :memory_trend,
                severity: :medium,
                message: "Memory usage is trending upward",
                suggestion: "Implement regular memory cleanup or object pooling"
              }
            end
            
            recommendations
          end

          private

          def current_memory_usage
            if defined?(GC)
              GC.stat[:heap_allocated_pages] * GC::INTERNAL_CONSTANTS[:HEAP_PAGE_SIZE] / 1024.0 / 1024.0
            else
              0
            end
          rescue
            0
          end

          def remove_redundant_context_data
            context = workflow_execution.context_data.dup
            
            # Remove duplicate values
            seen_values = {}
            context.each do |key, value|
              value_hash = value.hash
              if seen_values[value_hash]
                # Replace with reference to first occurrence
                context[key] = { '_duplicate_of' => seen_values[value_hash] }
              else
                seen_values[value_hash] = key
              end
            end
            
            context
          end

          def compress_large_context_values(context)
            context.each do |key, value|
              if value.is_a?(String) && value.bytesize > 1.kilobyte
                # Simple compression simulation - in practice use zlib or similar
                compressed_value = {
                  '_compressed' => true,
                  '_original_size' => value.bytesize,
                  '_data' => value[0..100] + '...[compressed]'
                }
                context[key] = compressed_value
              end
            end
            
            context
          end

          def compress_step_history(history)
            # Remove redundant timestamp precision
            history.map do |step|
              step.merge(
                'timestamp' => Time.parse(step['timestamp']).strftime('%Y-%m-%d %H:%M:%S')
              )
            end
          end

          def find_expired_context_keys(context)
            expired_keys = []
            
            context.each do |key, value|
              if value.is_a?(Hash) && value['expires_at']
                expires_at = Time.parse(value['expires_at']) rescue nil
                if expires_at && expires_at < Time.current
                  expired_keys << key
                end
              end
            end
            
            expired_keys
          end

          def memory_usage_trending_up?
            # Simplified trend detection - in practice would track over time
            current_memory_usage > 50.megabytes
          end
        end

        # Performance optimization coordinator
        class PerformanceOptimizer
          attr_reader :workflow_execution, :query_optimizer, :memory_optimizer

          def initialize(workflow_execution)
            @workflow_execution = workflow_execution
            @query_optimizer = QueryOptimizer.new(workflow_execution)
            @memory_optimizer = MemoryOptimizer.new(workflow_execution)
          end

          # Run comprehensive performance optimization
          #
          # @param options [Hash] optimization options
          # @return [Hash] comprehensive optimization results
          def optimize_performance(options = {})
            start_time = Time.current
            
            results = {
              started_at: start_time,
              query_optimization: nil,
              memory_optimization: nil,
              overall_impact: nil
            }
            
            # Query optimization
            if options.fetch(:optimize_queries, true)
              results[:query_optimization] = optimize_queries
            end
            
            # Memory optimization
            if options.fetch(:optimize_memory, true)
              results[:memory_optimization] = optimize_memory
            end
            
            # Calculate overall impact
            results[:overall_impact] = calculate_overall_impact(results)
            results[:completed_at] = Time.current
            results[:total_time] = results[:completed_at] - start_time
            
            results
          end

          # Auto-optimize based on current performance metrics
          def auto_optimize
            monitor = Performance::Monitor.new(workflow_execution)
            recommendations = monitor.optimization_recommendations
            
            optimizations_applied = []
            
            recommendations.each do |rec|
              case rec[:type]
              when :memory
                if rec[:severity] == :high
                  result = memory_optimizer.optimize_memory_usage
                  optimizations_applied << result if result
                end
              when :database
                if rec[:severity] != :low
                  result = query_optimizer.optimize_queries_for_operation(:general)
                  optimizations_applied << result if result
                end
              end
            end
            
            {
              auto_optimizations: optimizations_applied,
              recommendations_processed: recommendations.size,
              optimizations_applied: optimizations_applied.size
            }
          end

          private

          def optimize_queries
            query_optimizer.optimize_queries_for_operation(:general)
          end

          def optimize_memory
            memory_optimizer.optimize_memory_usage
          end

          def calculate_overall_impact(results)
            impact = { score: 0, improvements: [] }
            
            # Query optimization impact
            if results[:query_optimization] && results[:query_optimization][:queries_saved] > 0
              impact[:score] += 20
              impact[:improvements] << "Reduced queries by #{results[:query_optimization][:queries_saved]}"
            end
            
            # Memory optimization impact
            if results[:memory_optimization] && results[:memory_optimization][:memory_saved] > 0
              impact[:score] += 30
              memory_mb = results[:memory_optimization][:memory_saved]
              impact[:improvements] << "Saved #{memory_mb.round(2)}MB memory"
            end
            
            # Overall assessment
            impact[:assessment] = case impact[:score]
                                 when 0..10 then 'minimal'
                                 when 11..30 then 'moderate'
                                 when 31..50 then 'significant'
                                 else 'substantial'
                                 end
            
            impact
          end
        end
      end
    end
  end
end