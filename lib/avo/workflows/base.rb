# frozen_string_literal: true

require 'set'

module Avo
  module Workflows
    # Base class for defining workflows using a DSL
    #
    # Workflows are defined by extending this class and using the `step` method
    # to define each step in the workflow with its available actions.
    #
    # @example Simple approval workflow
    #   class DocumentApprovalWorkflow < Avo::Workflows::Base
    #     step :draft do
    #       description "Document is being written"
    #       action :submit_for_review, to: :pending_review
    #       action :save_draft, to: :draft
    #     end
    #
    #     step :pending_review do
    #       description "Document awaiting review"
    #       action :approve, to: :approved
    #       action :reject, to: :rejected
    #       action :request_changes, to: :draft
    #     end
    #
    #     step :approved do
    #       description "Document has been approved"
    #       # No actions - this is a final step
    #     end
    #
    #     step :rejected do
    #       description "Document was rejected"
    #       action :resubmit, to: :draft
    #     end
    #   end
    class Base
      class << self
        # Returns the defined workflow steps
        # @return [Hash<Symbol, StepDefinition>] hash of step definitions
        attr_reader :workflow_steps

        # Called when a class inherits from Base
        # Sets up the workflow steps hash and handles auto-registration
        #
        # @param subclass [Class] the inheriting class
        def inherited(subclass)
          super
          subclass.instance_variable_set(:@workflow_steps, {})
        end

        # Defines a workflow step with its actions and conditions
        #
        # @param name [Symbol, String] the step name
        # @yield block to configure the step
        # @return [StepDefinition] the created step definition
        #
        # @example
        #   step :pending_review do
        #     description "Awaiting review"
        #     action :approve, to: :approved
        #     action :reject, to: :rejected
        #   end
        def step(name, &block)
          @workflow_steps ||= {}
          step_name = name.to_sym
          
          if @workflow_steps.key?(step_name)
            raise Error, "Step '#{step_name}' is already defined"
          end

          @workflow_steps[step_name] = StepDefinition.new(step_name)
          
          if block_given?
            @workflow_steps[step_name].instance_eval(&block)
          end
          
          @workflow_steps[step_name]
        end

        # Returns all defined step names in order
        #
        # @return [Array<Symbol>] array of step names
        def step_names
          @workflow_steps&.keys || []
        end

        # Finds a step definition by name
        #
        # @param name [Symbol, String] the step name to find
        # @return [StepDefinition, nil] the step definition or nil if not found
        def find_step(name)
          @workflow_steps&.[](name.to_sym)
        end

        # Returns steps that have no actions (final steps)
        #
        # @return [Array<Symbol>] array of final step names
        def final_steps
          step_names.select { |name| find_step(name).actions.empty? }
        end

        # Returns the first defined step (initial step)
        #
        # @return [Symbol, nil] the initial step name or nil if no steps defined
        def initial_step
          step_names.first
        end

        # Validates the workflow definition
        #
        # @return [Array<String>] array of validation errors
        def validate_definition
          errors = []
          
          if step_names.empty?
            errors << "Workflow must define at least one step"
            return errors
          end

          # Check for unreachable steps
          reachable_steps = Set.new([initial_step])
          
          step_names.each do |step_name|
            step_def = find_step(step_name)
            step_def.actions.each_value do |action_config|
              target_step = action_config[:to]
              reachable_steps << target_step
              
              unless find_step(target_step)
                errors << "Step '#{step_name}' has action targeting undefined step '#{target_step}'"
              end
            end
          end

          unreachable_steps = step_names.to_set - reachable_steps
          unreachable_steps.each do |step_name|
            errors << "Step '#{step_name}' is unreachable from initial step"
          end

          errors
        end

        # Creates a workflow execution for a workflowable record
        #
        # @param workflowable [ActiveRecord::Base] the record to attach workflow to
        # @param assigned_to [ActiveRecord::Base, nil] optional user to assign to
        # @param initial_context [Hash] initial context data
        # @return [WorkflowExecution] the created execution
        # @raise [Error] if workflow has no initial step
        def create_execution_for(workflowable, assigned_to: nil, initial_context: {})
          if initial_step.nil?
            raise Error, "Cannot create execution: workflow has no initial step"
          end

          Avo::Workflows.configuration.workflow_execution_model.create!(
            workflow_class: name,
            workflowable: workflowable,
            current_step: initial_step.to_s,
            assigned_to: assigned_to,
            context_data: initial_context
          )
        end
      end

      # Initializes a workflow instance
      #
      # @param execution [WorkflowExecution, nil] optional execution instance
      def initialize(execution = nil)
        @execution = execution
      end

      # Returns the workflow steps for this instance
      #
      # @return [Hash<Symbol, StepDefinition>] hash of step definitions
      def steps
        self.class.workflow_steps || {}
      end

      # Returns available actions for a step given the context
      #
      # @param step_name [Symbol, String] the step name
      # @param context [Hash] the execution context
      # @return [Array<Symbol>] array of available action names
      def available_actions_for_step(step_name, context = {})
        step_def = self.class.find_step(step_name)
        return [] unless step_def

        step_def.actions.filter_map do |action_name, action_config|
          # Check if action has conditions
          if action_config[:condition]
            # Call condition in the context of the workflow class
            begin
              self.class.instance_exec(context, &action_config[:condition]) ? action_name : nil
            rescue => e
              # If condition evaluation fails, exclude the action
              nil
            end
          else
            action_name
          end
        end
      end

      # Checks if a transition from one step to another via an action is valid
      #
      # @param from_step [Symbol, String] the source step
      # @param action [Symbol, String] the action name
      # @param to_step [Symbol, String] the target step
      # @return [Boolean] true if transition is valid
      def can_transition?(from_step, action, to_step)
        step_def = self.class.find_step(from_step)
        return false unless step_def

        action_config = step_def.actions[action.to_sym]
        return false unless action_config

        action_config[:to] == to_step.to_sym
      end

      # Checks if a step is a final step (has no actions)
      #
      # @param step_name [Symbol, String] the step name to check
      # @return [Boolean] true if step is final
      def final_step?(step_name)
        self.class.final_steps.include?(step_name.to_sym)
      end

      # Step definition helper class
      #
      # Used within step blocks to define actions, conditions, and metadata
      class StepDefinition
        # Step name
        # @return [Symbol] the step name
        attr_reader :name
        
        # Step actions
        # @return [Hash<Symbol, Hash>] hash of action configurations
        attr_reader :actions
        
        # Step conditions
        # @return [Array<Proc>] array of condition blocks
        attr_reader :conditions
        
        # Step description
        # @return [String, nil] optional step description
        attr_reader :description
        
        # Step requirements
        # @return [Array<String>] array of requirement descriptions
        attr_reader :requirements

        # Initializes a step definition
        #
        # @param name [Symbol] the step name
        def initialize(name)
          @name = name
          @actions = {}
          @conditions = []
          @requirements = []
          @description = nil
        end

        # Sets the step description when called from step block
        #
        # @param text [String] description text
        # @return [String] the description
        def describe(text)
          @description = text
        end

        # Adds a requirement for this step
        #
        # @param text [String] requirement description
        # @return [Array<String>] current requirements
        def requirement(text)
          @requirements << text
        end

        # Defines an action that can be taken from this step
        #
        # @param action_name [Symbol, String] the action name
        # @param to [Symbol, String] the target step
        # @param condition [Proc, nil] optional condition block
        # @param description [String, nil] optional action description
        # @param confirmation_required [Boolean] whether action requires confirmation
        # @return [Hash] the action configuration
        def action(action_name, to:, condition: nil, description: nil, confirmation_required: false)
          action_sym = action_name.to_sym
          
          if @actions.key?(action_sym)
            raise Error, "Action '#{action_sym}' is already defined for step '#{@name}'"
          end

          @actions[action_sym] = {
            to: to.to_sym,
            condition: condition,
            description: description,
            confirmation_required: confirmation_required
          }
        end

        # Adds a condition that must be satisfied for this step
        #
        # @yield condition block that receives context and returns boolean
        # @return [Array<Proc>] current conditions
        def condition(&block)
          @conditions << block if block_given?
          @conditions
        end

        # Checks if all step conditions are satisfied
        #
        # @param context [Hash] the execution context
        # @return [Boolean] true if all conditions are satisfied
        def satisfies_conditions?(context)
          @conditions.all? { |condition| condition.call(context) }
        end

        # Checks if an action requires confirmation
        #
        # @param action_name [Symbol, String] the action name
        # @return [Boolean] true if confirmation is required
        def confirmation_required?(action_name)
          action_config = @actions[action_name.to_sym]
          action_config&.dig(:confirmation_required) || false
        end
      end
    end
  end
end