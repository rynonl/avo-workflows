# frozen_string_literal: true

module Avo
  module Workflows
    class Base
      class << self
        attr_reader :workflow_steps

        def inherited(subclass)
          super
          # Note: Auto-registration happens when the class gets a proper name
          # For immediate registration of named classes, call Registry.register manually
        end

        def step(name, &block)
          @workflow_steps ||= {}
          @workflow_steps[name] = StepDefinition.new(name)
          
          if block_given?
            @workflow_steps[name].instance_eval(&block)
          end
          
          @workflow_steps[name]
        end

        def step_names
          @workflow_steps&.keys || []
        end

        def find_step(name)
          @workflow_steps&.[](name.to_sym)
        end

        def final_steps
          step_names.select { |name| find_step(name).actions.empty? }
        end

        def initial_step
          step_names.first
        end
      end

      def initialize(execution = nil)
        @execution = execution
      end

      def steps
        self.class.workflow_steps || {}
      end

      def available_actions_for_step(step_name, context = {})
        step_def = self.class.find_step(step_name)
        return [] unless step_def

        step_def.actions.select do |action_name, action_config|
          # Check if action has conditions
          if action_config[:condition]
            action_config[:condition].call(context)
          else
            true
          end
        end.keys
      end

      def can_transition?(from_step, action, to_step)
        step_def = self.class.find_step(from_step)
        return false unless step_def

        action_config = step_def.actions[action.to_sym]
        return false unless action_config

        action_config[:to] == to_step.to_sym
      end

      def final_step?(step_name)
        self.class.final_steps.include?(step_name.to_sym)
      end

      # Create execution for a workflowable record
      def self.create_execution_for(workflowable, assigned_to: nil, initial_context: {})
        Avo::Workflows.configuration.workflow_execution_model.create!(
          workflow_class: name,
          workflowable: workflowable,
          current_step: initial_step.to_s,
          assigned_to: assigned_to,
          context_data: initial_context
        )
      end

      # Helper class for defining steps
      class StepDefinition
        attr_reader :name, :actions, :conditions

        def initialize(name)
          @name = name
          @actions = {}
          @conditions = []
        end

        def action(action_name, to:, condition: nil)
          @actions[action_name.to_sym] = {
            to: to.to_sym,
            condition: condition
          }
        end

        def condition(&block)
          @conditions << block if block_given?
        end

        def satisfies_conditions?(context)
          @conditions.all? { |condition| condition.call(context) }
        end
      end
    end
  end
end