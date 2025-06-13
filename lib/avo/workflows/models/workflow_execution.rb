# frozen_string_literal: true

require 'active_record'
require 'workflow'

module Avo
  module Workflows
    class WorkflowExecution < ActiveRecord::Base
      include Workflow

      self.table_name = 'avo_workflow_executions'

      # Associations
      belongs_to :workflowable, polymorphic: true
      belongs_to :assigned_to, polymorphic: true, optional: true

      # Validations
      validates :workflow_class, presence: true
      validates :current_step, presence: true
      validates :status, inclusion: { in: %w[active completed failed paused] }
      validate :validate_workflow_definition
      validate :validate_current_step

      # Scopes
      scope :active, -> { where(status: 'active') }
      scope :completed, -> { where(status: 'completed') }
      scope :failed, -> { where(status: 'failed') }
      scope :paused, -> { where(status: 'paused') }
      scope :for_workflow, ->(workflow_class) { where(workflow_class: workflow_class.to_s) }

      # JSON columns are automatically handled in Rails 7+

      # Initialize defaults
      after_initialize :set_defaults

      # Workflow state management (using current_step column)
      def current_state
        current_step&.to_sym
      end

      def current_state=(new_state)
        self.current_step = new_state.to_s
      end

      # Instance methods
      def workflow_definition
        @workflow_definition ||= workflow_class.constantize.new
      end

      def can_transition_to?(target_step)
        available_actions.any? do |action_name|
          step_def = workflow_definition.class.find_step(current_step.to_sym)
          step_def&.actions&.[](action_name)&.[](:to) == target_step.to_sym
        end
      end

      def available_actions
        workflow_definition.available_actions_for_step(current_step.to_sym, context_data)
      end

      def perform_action(action_name, user: nil, additional_context: {})
        # Create checkpoint before action
        checkpoint_id = create_recovery_checkpoint("Before #{action_name}")

        # Validate the transition before attempting
        validation_errors = Validators.validate_transition(self, action_name)
        if validation_errors.any?
          errors.add(:base, validation_errors.join('; '))
          return false
        end

        old_step = current_step
        new_context = (context_data || {}).merge(additional_context)

        # Find the target step for this action
        step_def = workflow_definition.class.find_step(current_step.to_sym)
        action_config = step_def.actions[action_name.to_sym]
        
        unless action_config
          error = InvalidActionError.new(
            "Action '#{action_name}' not available in step '#{current_step}'",
            workflow_execution: self,
            details: { action: action_name, current_step: current_step }
          )
          handle_workflow_error(error)
          return false
        end

        target_step = action_config[:to].to_s

        begin
          # Update to new step and context
          update!(
            current_step: target_step,
            context_data: new_context,
            assigned_to: user
          )

          # Record the transition in history
          record_transition(old_step, target_step, action_name, user)

          # Check if workflow is complete
          update!(status: 'completed') if workflow_definition.final_step?(target_step.to_sym)

          # Log successful transition
          log_workflow_event(:transition_success, action_name, old_step, target_step)

          true
        rescue ActiveRecord::RecordInvalid => e
          # Handle validation errors with recovery info
          error = WorkflowExecutionError.new(
            "Transition validation failed: #{e.message}",
            workflow_execution: self,
            context: { action: action_name, from: old_step, to: target_step },
            details: { checkpoint_id: checkpoint_id }
          )
          handle_workflow_error(error)
          false
        rescue => e
          # Handle other errors with full context
          error = WorkflowExecutionError.new(
            "Transition failed: #{e.message}",
            workflow_execution: self,
            context: { action: action_name, from: old_step, to: target_step },
            details: { 
              checkpoint_id: checkpoint_id,
              original_error: e.class.name,
              backtrace: e.backtrace&.first(5)
            }
          )
          handle_workflow_error(error)
          raise error
        end
      end

      def context_value(key)
        context_data&.dig(key.to_s)
      end

      def set_context_value(key, value)
        self.context_data = (context_data || {}).merge(key.to_s => value)
      end

      def history
        step_history || []
      end

      # Helper method for tests - updates context data
      # 
      # @param new_context [Hash] new context data to merge  
      def update_context!(new_context)
        return unless new_context.is_a?(Hash)
        
        current_context = context_data || {}
        merged_context = current_context.merge(new_context)
        
        update!(context_data: merged_context)
      end

      # Error handling and recovery methods

      # Handle workflow errors with comprehensive logging
      def handle_workflow_error(error)
        update_column(:status, 'failed')
        
        # Log the error
        log_workflow_event(:error, error.class.name, error.message, error.to_h)
        
        # Add to ActiveRecord errors
        errors.add(:base, error.message)
        
        # Store error details in context for debugging
        error_context = {
          '_last_error' => {
            timestamp: Time.current.iso8601,
            error_class: error.class.name,
            message: error.message,
            details: error.details,
            context: error.context
          }
        }
        
        begin
          update_context!(error_context)
        rescue
          # If we can't update context, at least log it
          log_workflow_event(:error_context_update_failed, error.to_h)
        end
      end

      # Create a recovery checkpoint
      def create_recovery_checkpoint(label = nil)
        begin
          Recovery::WorkflowRecovery.new(self).create_checkpoint(label)
        rescue => e
          log_workflow_event(:checkpoint_creation_failed, e.message)
          nil
        end
      end

      # Get debug information for this execution
      def debug_info
        Debugging::WorkflowDebugger.new(self).debug_report
      end

      # Validate workflow integrity
      def validate_integrity
        Recovery::WorkflowRecovery.new(self).validate_integrity
      end

      # Attempt automatic recovery
      def recover!(strategy: :auto, **options)
        Recovery::WorkflowRecovery.new(self).recover!(strategy: strategy, **options)
      end

      # Get execution trace for debugging
      def execution_trace
        Debugging::WorkflowDebugger.new(self).execution_trace
      end

      # Suggest next possible actions
      def suggest_next_actions
        Debugging::WorkflowDebugger.new(self).suggest_next_actions
      end

      # Simulate action outcome without executing
      def simulate_action(action_name, test_context: {})
        Debugging::WorkflowDebugger.new(self).simulate_action(action_name, test_context: test_context)
      end

      # Export comprehensive diagnostics
      def export_diagnostics(format: :json)
        Recovery::WorkflowRecovery.new(self).export_diagnostics(format: format)
      end

      # Check if execution can be recovered
      def recoverable?
        Recovery::WorkflowRecovery.new(self).can_recover?
      end

      # List recovery blockers
      def recovery_blockers
        Recovery::WorkflowRecovery.new(self).recovery_blockers
      end

      # Generate recovery plan
      def recovery_plan
        Recovery::WorkflowRecovery.new(self).recovery_plan
      end

      # List available checkpoints
      def list_checkpoints
        Recovery::WorkflowRecovery.new(self).list_checkpoints
      end

      # Restore from checkpoint
      def restore_from_checkpoint!(checkpoint_id, force: false)
        Recovery::WorkflowRecovery.new(self).restore_from_checkpoint!(checkpoint_id, force: force)
      end

      private

      def set_defaults
        self.context_data ||= {}
        self.step_history ||= []
        self.status ||= 'active'
      end

      def record_transition(from_step, to_step, action, user)
        transition_record = {
          from_step: from_step,
          to_step: to_step,
          action: action.to_s,
          user_id: user&.id,
          user_type: user&.class&.name,
          timestamp: Time.current.iso8601
        }

        self.step_history = history + [transition_record]
        save!
      end

      def validate_workflow_definition
        return unless workflow_class.present?

        validation_errors = Validators.validate_execution(self)
        validation_errors.each do |error|
          errors.add(:base, error)
        end
      end

      def validate_current_step
        return unless workflow_class.present? && current_step.present?

        begin
          workflow_def = workflow_definition
          unless workflow_def.class.step_names.include?(current_step.to_sym)
            errors.add(:current_step, "is not a valid step for #{workflow_class}")
          end
        rescue NameError
          errors.add(:workflow_class, "not found")
        end
      end

      def log_workflow_event(event_type, *args)
        return unless Rails.logger

        message = case event_type
        when :transition_success
          action, from_step, to_step = args
          "Workflow transition: #{action} (#{from_step} -> #{to_step})"
        when :error
          error_class, error_message, details = args
          "Workflow error: #{error_class} - #{error_message}"
        when :checkpoint_creation_failed
          error_message = args.first
          "Checkpoint creation failed: #{error_message}"
        when :error_context_update_failed
          details = args.first
          "Error context update failed: #{details}"
        else
          "Workflow event: #{event_type} - #{args.join(', ')}"
        end

        Rails.logger.info "[WorkflowExecution:#{id}] #{message}"
      rescue => e
        # Fail silently if logging fails
        nil
      end
    end
  end
end