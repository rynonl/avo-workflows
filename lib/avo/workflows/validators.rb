# frozen_string_literal: true

require 'set'

module Avo
  module Workflows
    class Validators
      class << self
        def validate_workflow_definition(workflow_class)
          errors = []
          
          # Check if workflow has steps
          if workflow_class.step_names.empty?
            errors << "Workflow #{workflow_class.name} must define at least one step"
          end

          # Validate each step
          workflow_class.step_names.each do |step_name|
            step_errors = validate_step(workflow_class, step_name)
            errors.concat(step_errors)
          end

          # Check for unreachable steps (except initial step)
          unreachable_steps = find_unreachable_steps(workflow_class)
          if unreachable_steps.any?
            errors << "Unreachable steps found: #{unreachable_steps.join(', ')}"
          end

          errors
        end

        def validate_step(workflow_class, step_name)
          errors = []
          step_def = workflow_class.find_step(step_name)
          
          return errors unless step_def

          # Validate action targets exist
          step_def.actions.each do |action_name, action_config|
            target_step = action_config[:to]
            unless workflow_class.step_names.include?(target_step)
              errors << "Step '#{step_name}' action '#{action_name}' targets non-existent step '#{target_step}'"
            end
          end

          errors
        end

        def validate_execution(execution)
          errors = []

          # Validate workflow class exists and is valid
          begin
            workflow_def = execution.workflow_definition
          rescue NameError
            errors << "Workflow class '#{execution.workflow_class}' not found"
            return errors
          end

          # Validate current step exists
          if execution.current_step.nil?
            errors << "Current step cannot be nil"
          elsif !workflow_def.class.step_names.include?(execution.current_step.to_sym)
            errors << "Current step '#{execution.current_step}' is not defined in workflow"
          end

          # Validate context data if there are requirements
          # This could be extended based on specific workflow needs

          errors
        end

        def validate_transition(execution, action_name)
          errors = []

          # Check if action is available
          unless execution.available_actions.include?(action_name.to_sym)
            errors << "Action '#{action_name}' is not available from step '#{execution.current_step}'"
          end

          # Validate step conditions if any
          step_def = execution.workflow_definition.class.find_step(execution.current_step.to_sym)
          if step_def && step_def.conditions.any?
            unless step_def.satisfies_conditions?(execution.context_data || {})
              errors << "Step conditions not satisfied for '#{execution.current_step}'"
            end
          end

          errors
        end

        private

        def find_unreachable_steps(workflow_class)
          initial_step = workflow_class.initial_step
          reachable_steps = Set.new([initial_step])
          queue = [initial_step]

          while queue.any?
            current_step = queue.shift
            step_def = workflow_class.find_step(current_step)
            
            next unless step_def

            step_def.actions.each do |_, action_config|
              target_step = action_config[:to]
              unless reachable_steps.include?(target_step)
                reachable_steps.add(target_step)
                queue.push(target_step)
              end
            end
          end

          workflow_class.step_names - reachable_steps.to_a
        end
      end
    end
  end
end