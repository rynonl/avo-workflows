# frozen_string_literal: true

module Avo
  module Workflows
    # Comprehensive debugging utilities for workflow development and troubleshooting
    module Debugging
      class WorkflowDebugger
        attr_reader :workflow_execution, :logger

        def initialize(workflow_execution, logger: nil)
          @workflow_execution = workflow_execution
          @logger = logger || default_logger
        end

        # Generate comprehensive debug report
        def debug_report
          {
            execution_summary: execution_summary,
            current_state: current_state_analysis,
            available_actions: available_actions_analysis,
            context_analysis: context_analysis,
            validation_status: validation_status,
            history_analysis: history_analysis,
            performance_metrics: performance_metrics,
            potential_issues: potential_issues
          }
        end

        # Validate current workflow state for consistency
        def validate_state
          issues = []
          
          # Check if current step exists in workflow definition
          unless workflow_definition.class.step_names.include?(current_step)
            issues << "Current step '#{current_step}' not defined in workflow"
          end

          # Validate context data structure
          context_issues = validate_context_structure
          issues.concat(context_issues)

          # Check for orphaned data
          orphaned_data = find_orphaned_context_data
          issues.concat(orphaned_data) if orphaned_data.any?

          # Validate step requirements
          requirement_issues = validate_step_requirements
          issues.concat(requirement_issues)

          issues
        end

        # Trace execution path from start to current step
        def execution_trace
          return [] unless workflow_execution.step_history

          workflow_execution.step_history.map.with_index do |transition, index|
            {
              step_number: index + 1,
              from_step: transition['from_step'],
              to_step: transition['to_step'],
              action: transition['action'],
              user: user_info(transition),
              timestamp: transition['timestamp'],
              duration: calculate_step_duration(index),
              context_changes: analyze_context_changes(index)
            }
          end
        end

        # Suggest next possible actions with validation details
        def suggest_next_actions
          available_actions = workflow_execution.available_actions
          
          available_actions.map do |action_name|
            action_info = get_action_info(action_name)
            validation_result = validate_action_conditions(action_name)
            
            {
              action: action_name,
              target_step: action_info[:to],
              description: action_info[:description],
              requires_confirmation: action_info[:confirmation_required],
              condition_met: validation_result[:valid],
              condition_details: validation_result[:details],
              estimated_time: estimate_action_time(action_name),
              required_permissions: analyze_action_permissions(action_name)
            }
          end
        end

        # Simulate potential action outcomes
        def simulate_action(action_name, test_context: {})
          return { error: "Action not available" } unless workflow_execution.available_actions.include?(action_name)

          # Create a temporary context for simulation
          simulation_context = workflow_execution.context_data.merge(test_context)
          
          begin
            action_info = get_action_info(action_name)
            target_step = action_info[:to]
            
            # Validate conditions with simulation context
            condition_result = validate_action_with_context(action_name, simulation_context)
            
            {
              action: action_name,
              target_step: target_step,
              would_succeed: condition_result[:valid],
              validation_details: condition_result[:details],
              context_requirements: analyze_context_requirements(action_name),
              side_effects: predict_side_effects(action_name, target_step),
              warnings: generate_warnings(action_name, simulation_context)
            }
          rescue => e
            {
              action: action_name,
              would_succeed: false,
              error: e.message,
              error_type: e.class.name
            }
          end
        end

        # Find potential deadlocks or unreachable states
        def analyze_workflow_graph
          analysis = {
            reachable_steps: [],
            unreachable_steps: [],
            potential_deadlocks: [],
            cycle_detection: [],
            final_states: []
          }

          workflow_steps = workflow_definition.class.step_names
          
          # Build transition graph
          transition_graph = build_transition_graph

          # Analyze reachability from current step
          analysis[:reachable_steps] = find_reachable_steps(current_step, transition_graph)
          analysis[:unreachable_steps] = workflow_steps - analysis[:reachable_steps]

          # Detect potential cycles
          analysis[:cycle_detection] = detect_cycles(transition_graph)

          # Find final states
          analysis[:final_states] = workflow_definition.class.final_steps

          # Check for deadlocks (steps with no outgoing transitions)
          analysis[:potential_deadlocks] = find_potential_deadlocks(transition_graph)

          analysis
        end

        # Generate performance report
        def performance_report
          history = workflow_execution.step_history || []
          return { message: "No execution history available" } if history.empty?

          {
            total_execution_time: calculate_total_execution_time,
            average_step_time: calculate_average_step_time,
            slowest_steps: find_slowest_steps,
            fastest_steps: find_fastest_steps,
            step_efficiency: calculate_step_efficiency,
            bottlenecks: identify_bottlenecks,
            recommendations: generate_performance_recommendations
          }
        end

        # Export debug data for external analysis
        def export_debug_data(format: :json)
          data = {
            workflow_execution: workflow_execution.attributes,
            debug_report: debug_report,
            execution_trace: execution_trace,
            validation_results: validate_state,
            graph_analysis: analyze_workflow_graph,
            performance_data: performance_report,
            exported_at: Time.current.iso8601
          }

          case format
          when :json
            JSON.pretty_generate(data)
          when :yaml
            YAML.dump(data)
          else
            data
          end
        end

        private

        def workflow_definition
          @workflow_definition ||= workflow_execution.workflow_definition
        end

        def current_step
          workflow_execution.current_step.to_sym
        end

        def default_logger
          Rails.logger if defined?(Rails)
        end

        def execution_summary
          {
            id: workflow_execution.id,
            workflow_class: workflow_execution.workflow_class,
            current_step: workflow_execution.current_step,
            status: workflow_execution.status,
            started_at: workflow_execution.created_at,
            last_updated: workflow_execution.updated_at,
            total_steps: workflow_execution.step_history&.length || 0
          }
        end

        def current_state_analysis
          step_definition = workflow_definition.class.find_step(current_step)
          {
            step_name: current_step,
            description: step_definition&.description,
            requirements: step_definition&.requirements || [],
            available_actions: workflow_execution.available_actions.length,
            is_final_step: workflow_definition.final_step?(current_step)
          }
        end

        def available_actions_analysis
          workflow_execution.available_actions.map do |action|
            action_info = get_action_info(action)
            {
              action: action,
              target_step: action_info[:to],
              description: action_info[:description],
              has_condition: action_info[:condition].present?,
              requires_confirmation: action_info[:confirmation_required]
            }
          end
        end

        def context_analysis
          context = workflow_execution.context_data || {}
          {
            total_keys: context.keys.length,
            nested_levels: calculate_nesting_depth(context),
            data_types: analyze_data_types(context),
            size_estimate: context.to_s.bytesize,
            null_values: count_null_values(context),
            empty_collections: count_empty_collections(context)
          }
        end

        def validation_status
          issues = validate_state
          {
            is_valid: issues.empty?,
            issue_count: issues.length,
            issues: issues,
            last_validated: Time.current.iso8601
          }
        end

        def history_analysis
          history = workflow_execution.step_history || []
          {
            total_transitions: history.length,
            unique_users: count_unique_users(history),
            step_frequency: calculate_step_frequency(history),
            action_frequency: calculate_action_frequency(history),
            backtracking_instances: count_backtracking(history)
          }
        end

        def performance_metrics
          {
            execution_time: calculate_total_execution_time,
            average_step_duration: calculate_average_step_time,
            context_size: workflow_execution.context_data&.to_s&.bytesize || 0,
            history_size: workflow_execution.step_history&.to_s&.bytesize || 0
          }
        end

        def potential_issues
          issues = []
          
          # Check for stale executions
          if workflow_execution.updated_at < 24.hours.ago
            issues << "Workflow execution hasn't been updated in over 24 hours"
          end

          # Check for excessive context size
          context_size = workflow_execution.context_data&.to_s&.bytesize || 0
          if context_size > 10.kilobytes
            issues << "Context data is unusually large (#{context_size} bytes)"
          end

          # Check for cycles in history
          if detect_execution_cycles.any?
            issues << "Potential infinite loops detected in execution history"
          end

          issues
        end

        def validate_context_structure
          issues = []
          context = workflow_execution.context_data || {}

          # Check for required context keys based on current step
          required_keys = determine_required_context_keys(current_step)
          missing_keys = required_keys - context.keys
          
          missing_keys.each do |key|
            issues << "Missing required context key: #{key}"
          end

          issues
        end

        def find_orphaned_context_data
          # This would be customized based on your workflow requirements
          []
        end

        def validate_step_requirements
          issues = []
          step_definition = workflow_definition.class.find_step(current_step)
          return issues unless step_definition

          requirements = step_definition.requirements || []
          # This would validate actual requirements against current state
          # Implementation depends on your specific requirement validation logic

          issues
        end

        def user_info(transition)
          return "Unknown" unless transition['user_id']
          "User #{transition['user_id']} (#{transition['user_type']})"
        end

        def calculate_step_duration(index)
          history = workflow_execution.step_history
          return "N/A" if index >= history.length - 1

          current_time = Time.parse(history[index]['timestamp'])
          next_time = Time.parse(history[index + 1]['timestamp'])
          
          duration = next_time - current_time
          format_duration(duration)
        rescue
          "N/A"
        end

        def format_duration(seconds)
          if seconds < 60
            "#{seconds.round(1)}s"
          elsif seconds < 3600
            "#{(seconds / 60).round(1)}m"
          else
            "#{(seconds / 3600).round(1)}h"
          end
        end

        def analyze_context_changes(index)
          # This would compare context before and after each step
          # Implementation depends on whether you store context history
          "Changes not tracked"
        end

        def get_action_info(action_name)
          step_definition = workflow_definition.class.find_step(current_step)
          step_definition.actions[action_name.to_sym] || {}
        end

        def validate_action_conditions(action_name)
          action_info = get_action_info(action_name)
          condition = action_info[:condition]
          
          if condition
            begin
              result = condition.call(workflow_execution.context_data)
              { valid: result, details: "Condition evaluated to #{result}" }
            rescue => e
              { valid: false, details: "Condition error: #{e.message}" }
            end
          else
            { valid: true, details: "No condition specified" }
          end
        end

        def validate_action_with_context(action_name, context)
          action_info = get_action_info(action_name)
          condition = action_info[:condition]
          
          if condition
            begin
              result = condition.call(context)
              { valid: result, details: "Condition evaluated to #{result} with test context" }
            rescue => e
              { valid: false, details: "Condition error with test context: #{e.message}" }
            end
          else
            { valid: true, details: "No condition specified" }
          end
        end

        def estimate_action_time(action_name)
          # This could be based on historical data
          "Unknown"
        end

        def analyze_action_permissions(action_name)
          # This would analyze what permissions are needed for the action
          []
        end

        def analyze_context_requirements(action_name)
          # Analyze what context data the action needs
          []
        end

        def predict_side_effects(action_name, target_step)
          # Predict what side effects the action might have
          []
        end

        def generate_warnings(action_name, context)
          # Generate warnings about the action in the given context
          []
        end

        def build_transition_graph
          graph = {}
          
          workflow_definition.class.step_names.each do |step_name|
            step_def = workflow_definition.class.find_step(step_name)
            next unless step_def

            graph[step_name] = step_def.actions.values.map { |action| action[:to] }.compact
          end

          graph
        end

        def find_reachable_steps(start_step, graph, visited = Set.new)
          return Set.new if visited.include?(start_step)
          
          visited.add(start_step)
          reachable = Set.new([start_step])

          (graph[start_step] || []).each do |next_step|
            reachable.merge(find_reachable_steps(next_step, graph, visited.dup))
          end

          reachable.to_a
        end

        def detect_cycles(graph)
          # Simple cycle detection - could be made more sophisticated
          cycles = []
          
          graph.each do |step, targets|
            targets.each do |target|
              if graph[target]&.include?(step)
                cycles << [step, target]
              end
            end
          end

          cycles
        end

        def find_potential_deadlocks(graph)
          deadlocks = []
          
          graph.each do |step, targets|
            if targets.empty? && !workflow_definition.final_step?(step)
              deadlocks << step
            end
          end

          deadlocks
        end

        def calculate_total_execution_time
          history = workflow_execution.step_history || []
          return 0 if history.length < 2

          start_time = Time.parse(history.first['timestamp'])
          end_time = Time.parse(history.last['timestamp'])
          
          format_duration(end_time - start_time)
        rescue
          "N/A"
        end

        def calculate_average_step_time
          # Implementation for average step calculation
          "N/A"
        end

        def find_slowest_steps
          []
        end

        def find_fastest_steps
          []
        end

        def calculate_step_efficiency
          {}
        end

        def identify_bottlenecks
          []
        end

        def generate_performance_recommendations
          []
        end

        def calculate_nesting_depth(obj, current_depth = 0)
          return current_depth unless obj.is_a?(Hash) || obj.is_a?(Array)

          max_depth = current_depth
          
          if obj.is_a?(Hash)
            obj.values.each do |value|
              depth = calculate_nesting_depth(value, current_depth + 1)
              max_depth = [max_depth, depth].max
            end
          elsif obj.is_a?(Array)
            obj.each do |item|
              depth = calculate_nesting_depth(item, current_depth + 1)
              max_depth = [max_depth, depth].max
            end
          end

          max_depth
        end

        def analyze_data_types(obj)
          types = {}
          
          case obj
          when Hash
            obj.each_value do |value|
              sub_types = analyze_data_types(value)
              sub_types.each { |type, count| types[type] = (types[type] || 0) + count }
            end
          when Array
            obj.each do |item|
              sub_types = analyze_data_types(item)
              sub_types.each { |type, count| types[type] = (types[type] || 0) + count }
            end
          else
            type_name = obj.class.name
            types[type_name] = (types[type_name] || 0) + 1
          end

          types
        end

        def count_null_values(obj)
          case obj
          when Hash
            count = obj.values.count(&:nil?)
            obj.values.each { |value| count += count_null_values(value) }
            count
          when Array
            count = obj.count(&:nil?)
            obj.each { |item| count += count_null_values(item) }
            count
          else
            0
          end
        end

        def count_empty_collections(obj)
          case obj
          when Hash
            count = obj.values.count { |v| (v.is_a?(Hash) || v.is_a?(Array)) && v.empty? }
            obj.values.each { |value| count += count_empty_collections(value) }
            count
          when Array
            count = obj.count { |v| (v.is_a?(Hash) || v.is_a?(Array)) && v.empty? }
            obj.each { |item| count += count_empty_collections(item) }
            count
          else
            0
          end
        end

        def count_unique_users(history)
          history.map { |h| h['user_id'] }.compact.uniq.length
        end

        def calculate_step_frequency(history)
          frequency = Hash.new(0)
          history.each { |h| frequency[h['to_step']] += 1 }
          frequency
        end

        def calculate_action_frequency(history)
          frequency = Hash.new(0)
          history.each { |h| frequency[h['action']] += 1 }
          frequency
        end

        def count_backtracking(history)
          backtrack_count = 0
          visited_steps = Set.new
          
          history.each do |transition|
            step = transition['to_step']
            if visited_steps.include?(step)
              backtrack_count += 1
            end
            visited_steps.add(step)
          end

          backtrack_count
        end

        def detect_execution_cycles
          # Detect if the same step sequence has been repeated
          []
        end

        def determine_required_context_keys(step)
          # This would be customized based on your workflow step requirements
          []
        end
      end

      # Class methods for easy access
      def self.debug(workflow_execution)
        WorkflowDebugger.new(workflow_execution)
      end

      def self.validate(workflow_execution)
        debug(workflow_execution).validate_state
      end

      def self.trace(workflow_execution)
        debug(workflow_execution).execution_trace
      end

      def self.export(workflow_execution, format: :json)
        debug(workflow_execution).export_debug_data(format: format)
      end
    end
  end
end