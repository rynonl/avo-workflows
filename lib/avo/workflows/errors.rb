# frozen_string_literal: true

module Avo
  module Workflows
    # Base error class for all workflow-related errors
    #
    # Provides a structured approach to error handling in workflows with
    # rich context information and debugging capabilities.
    #
    # @example Basic usage
    #   error = Avo::Workflows::Error.new(
    #     "Something went wrong",
    #     workflow_execution: execution,
    #     context: { step: 'processing' },
    #     details: { retry_count: 3 }
    #   )
    #   puts error.to_h
    #
    # @example Error serialization
    #   error_data = error.to_h
    #   # => { error_class: "Avo::Workflows::Error", message: "...", ... }
    class Error < StandardError
      attr_reader :workflow_execution, :context, :details

      # Initialize a new workflow error
      #
      # @param message [String] the error message
      # @param workflow_execution [WorkflowExecution, nil] associated execution
      # @param context [Hash] additional context information
      # @param details [Hash] detailed error information
      def initialize(message, workflow_execution: nil, context: {}, details: {})
        super(message)
        @workflow_execution = workflow_execution
        @context = context || {}
        @details = details || {}
      end

      # Convert error to hash representation
      #
      # @return [Hash] serialized error information
      def to_h
        {
          error_class: self.class.name,
          message: message,
          timestamp: Time.current.iso8601,
          workflow_execution_id: workflow_execution&.id,
          current_step: workflow_execution&.current_step,
          workflow_class: workflow_execution&.workflow_class,
          context: serialize_context(context),
          details: serialize_context(details),
          backtrace: backtrace&.first(10)
        }
      end

      # Convert error to JSON string
      #
      # @return [String] JSON representation of the error
      def to_json(*args)
        JSON.generate(to_h, *args)
      end

      # Check if error is related to a specific workflow execution
      #
      # @param execution [WorkflowExecution] execution to check
      # @return [Boolean] true if error belongs to execution
      def belongs_to?(execution)
        workflow_execution == execution
      end

      # Check if error is retryable based on error type and context
      #
      # @return [Boolean] true if error might be resolved by retry
      def retryable?
        !is_a?(WorkflowDefinitionError) && !is_a?(PermissionError)
      end

      # Get severity level for the error
      #
      # @return [Symbol] severity level (:low, :medium, :high, :critical)
      def severity
        case self
        when WorkflowDefinitionError, StateCorruptionError
          :critical
        when TransitionError, ContextError
          :high
        when WorkflowExecutionError
          :medium
        else
          :low
        end
      end

      private

      # Safely serialize context objects to avoid circular references
      #
      # @param obj [Object] object to serialize
      # @return [Object] serialized object
      def serialize_context(obj)
        case obj
        when Hash
          obj.transform_values { |v| serialize_context(v) }
        when Array
          obj.map { |v| serialize_context(v) }
        when ActiveRecord::Base
          { class: obj.class.name, id: obj.id }
        when Time
          obj.iso8601
        when Symbol
          obj.to_s
        else
          obj.respond_to?(:to_s) ? obj.to_s : obj.inspect
        end
      rescue => e
        "<serialization_error: #{e.message}>"
      end
    end

    # Errors related to workflow definition problems
    #
    # These errors indicate issues with the workflow class definition itself,
    # such as invalid steps, actions, or configuration.
    class WorkflowDefinitionError < Error; end

    # Error raised when an invalid step is referenced
    #
    # @example
    #   raise InvalidStepError.new("Step 'invalid_step' not found in workflow")
    class InvalidStepError < WorkflowDefinitionError; end

    # Error raised when an invalid action is attempted
    #
    # @example  
    #   raise InvalidActionError.new("Action 'invalid_action' not available")
    class InvalidActionError < WorkflowDefinitionError; end

    # Error raised when workflow requirements are not met
    #
    # @example
    #   raise MissingRequirementError.new("Required field 'manager_id' missing")
    class MissingRequirementError < WorkflowDefinitionError; end

    # Errors related to workflow execution runtime problems
    #
    # These errors occur during workflow execution and may be retryable
    # depending on the specific circumstances.
    class WorkflowExecutionError < Error; end

    # Error raised when a workflow transition fails
    #
    # This is the base class for all transition-related errors.
    class TransitionError < WorkflowExecutionError; end

    # Error raised when transition conditions are not met
    #
    # @example
    #   raise ConditionNotMetError.new("Approval condition not satisfied")
    class ConditionNotMetError < TransitionError; end

    # Error raised when an invalid transition is attempted
    #
    # @example
    #   raise InvalidTransitionError.new("Cannot transition from 'completed' to 'draft'")
    class InvalidTransitionError < TransitionError; end

    # Error raised when workflow execution times out
    #
    # @example
    #   raise WorkflowTimeoutError.new("Workflow execution timed out after 30 minutes")
    class WorkflowTimeoutError < WorkflowExecutionError; end

    # Errors related to workflow context and data validation
    #
    # These errors indicate problems with the data passed to or stored
    # within the workflow execution context.
    class ContextError < Error; end

    # Error raised when context data is invalid or malformed
    #
    # @example
    #   raise InvalidContextError.new("Context data failed validation")
    class InvalidContextError < ContextError; end

    # Error raised when required context data is missing
    #
    # @example
    #   raise MissingContextError.new("Required context key 'employee_id' missing")
    class MissingContextError < ContextError; end

    # Error raised when context data validation fails
    #
    # @example
    #   raise ContextValidationError.new("Employee start_date must be in future")
    class ContextValidationError < ContextError; end

    # Errors related to workflow system configuration
    #
    # These errors indicate problems with the overall workflow system
    # configuration and setup.
    class ConfigurationError < Error; end

    # Error raised when required configuration is missing
    #
    # @example
    #   raise MissingConfigurationError.new("Workflow execution model not configured")
    class MissingConfigurationError < ConfigurationError; end

    # Error raised when configuration values are invalid
    #
    # @example
    #   raise InvalidConfigurationError.new("Invalid user_class configuration")
    class InvalidConfigurationError < ConfigurationError; end

    # Errors related to user permissions and authorization
    #
    # These errors indicate access control and permission problems.
    class PermissionError < Error; end

    # Error raised when user lacks required permissions
    #
    # @example
    #   raise UnauthorizedUserError.new("User lacks permission for this action")
    class UnauthorizedUserError < PermissionError; end

    # Error raised when required user is missing
    #
    # @example
    #   raise MissingUserError.new("Action requires a user but none provided")
    class MissingUserError < PermissionError; end

    # Errors related to workflow recovery and rollback operations
    #
    # These errors occur during recovery operations and indicate issues
    # with restoring workflow state.
    class RecoveryError < Error; end

    # Error raised when rollback operations fail
    #
    # @example
    #   raise RollbackError.new("Cannot rollback: checkpoint data corrupted")
    class RollbackError < RecoveryError; end

    # Error raised when workflow state corruption is detected
    #
    # @example
    #   raise StateCorruptionError.new("Workflow state consistency check failed")
    class StateCorruptionError < RecoveryError; end
  end
end