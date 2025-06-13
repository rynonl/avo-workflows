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

          true
        rescue ActiveRecord::RecordInvalid => e
          # Handle validation errors
          update_column(:status, 'failed')
          errors.add(:base, "Transition failed: #{e.message}")
          false
        rescue => e
          # Handle other errors
          update_column(:status, 'failed')
          errors.add(:base, "Transition failed: #{e.message}")
          raise e
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
    end
  end
end