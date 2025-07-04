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
      include Avo::Workflows::Forms::WorkflowFormMethods if defined?(Avo::Workflows::Forms::WorkflowFormMethods)
      
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

      # Performs a workflow action (used within on_submit blocks)
      #
      # This method allows on_submit handlers to trigger workflow transitions
      # after processing form data and executing business logic.
      #
      # @param action_name [Symbol, String] the action name to perform
      # @param user [Object] the user performing the action
      # @param additional_context [Hash] additional context data to merge
      # @return [Boolean] true if action was performed successfully
      # @raise [Error] if no execution is available or action fails
      # @example
      #   on_submit do |fields, user|
      #     Document.update!(comments: fields[:comments])
      #     perform_action(:approve, user: user)
      #   end
      def perform_action(action_name, user:, additional_context: {})
        unless @execution
          raise Error, "Cannot perform action: no workflow execution available"
        end

        @execution.perform_action(
          action_name, 
          user: user, 
          additional_context: additional_context
        )
      end

      # Access to current execution context (used within on_submit blocks)
      #
      # @return [Hash] current workflow execution context data
      # @example
      #   on_submit do |fields, user|
      #     current_priority = context[:priority]
      #     perform_action(:escalate, user: user) if current_priority == 'high'
      #   end
      def context
        @execution&.context_data || {}
      end

      # Updates workflow context data (used within on_submit blocks)
      #
      # @param new_data [Hash] data to merge into context
      # @return [Hash] updated context data
      # @example
      #   on_submit do |fields, user|
      #     update_context(
      #       review_comments: fields[:comments],
      #       reviewed_by: user.id,
      #       reviewed_at: Time.current
      #     )
      #     perform_action(:approve, user: user)
      #   end
      def update_context(new_data)
        if @execution
          @execution.update_context!(new_data)
        else
          raise Error, "Cannot update context: no workflow execution available"
        end
      end

      # Access to the workflowable object (used within on_submit blocks)
      #
      # @return [Object] the object this workflow is operating on
      # @example
      #   on_submit do |fields, user|
      #     workflowable.update!(status: fields[:status])
      #     perform_action(:complete, user: user)
      #   end
      def workflowable
        @execution&.workflowable
      end

      # Panel builder helper class
      #
      # Used within panel blocks to define form fields for step input
      class PanelBuilder
        # Field definitions
        # @return [Array<Hash>] array of field definitions
        attr_reader :fields

        # Initializes a panel builder
        def initialize
          @fields = []
        end

        # Defines a form field for the step panel
        #
        # @param name [Symbol, String] the field name
        # @param as [Symbol] the field type (:text, :textarea, :boolean, :select, etc.)
        # @param options [Hash] additional field options (required, label, help, etc.)
        # @return [Hash] the field definition
        # @example
        #   field :comments, as: :textarea, required: true, label: "Comments"
        #   field :priority, as: :select, options: ['low', 'medium', 'high']
        #   field :notify, as: :boolean, default: true
        def field(name, as:, **options)
          field_definition = {
            name: name.to_sym,
            type: as.to_sym,
            options: options
          }
          
          @fields << field_definition
          field_definition
        end
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
        
        # Panel fields
        # @return [Array<Hash>] array of field definitions for the step form panel
        attr_reader :panel_fields
        
        # On submit handler
        # @return [Proc, nil] block to execute when step form is submitted
        attr_reader :on_submit_handler

        # Initializes a step definition
        #
        # @param name [Symbol] the step name
        def initialize(name)
          @name = name
          @actions = {}
          @conditions = []
          @requirements = []
          @description = nil
          @panel_fields = []
          @on_submit_handler = nil
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

        # Defines the form panel for this step with fields for user input
        #
        # @yield panel block containing field definitions
        # @return [Array<Hash>] the panel field definitions
        # @example
        #   panel do
        #     field :comments, as: :textarea, required: true
        #     field :priority, as: :select, options: ['low', 'medium', 'high']
        #   end
        def panel(&block)
          return @panel_fields unless block_given?
          
          panel_builder = PanelBuilder.new
          panel_builder.instance_eval(&block)
          @panel_fields = panel_builder.fields
        end

        # Defines the handler for form submission
        #
        # The block receives form field data and current user, and should contain
        # the business logic to process the form submission and determine the next step.
        #
        # @yield on_submit block that receives (fields, user)
        # @yieldparam fields [Hash] form field data submitted by user
        # @yieldparam user [Object] current user performing the action
        # @return [Proc] the on_submit handler
        # @example
        #   on_submit do |fields, user|
        #     Document.update!(comments: fields[:comments])
        #     perform_action(:approve, user: user) if fields[:approved]
        #   end
        def on_submit(&block)
          return @on_submit_handler unless block_given?
          
          @on_submit_handler = block
        end

        # Checks if this step has a form panel
        #
        # @return [Boolean] true if step has panel fields defined
        def has_panel?
          @panel_fields.any?
        end

        # Checks if this step has an on_submit handler
        #
        # @return [Boolean] true if step has on_submit handler defined
        def has_on_submit_handler?
          @on_submit_handler.present?
        end
      end
    end
  end
end