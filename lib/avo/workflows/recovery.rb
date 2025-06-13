# frozen_string_literal: true

module Avo
  module Workflows
    # Comprehensive recovery and rollback system for workflow failures
    module Recovery
      class WorkflowRecovery
        attr_reader :workflow_execution, :logger

        def initialize(workflow_execution, logger: nil)
          @workflow_execution = workflow_execution
          @logger = logger || default_logger
        end

        # Attempt to recover a failed workflow
        def recover!(strategy: :auto, target_step: nil, force: false)
          log_recovery_attempt(strategy, target_step, force)

          # Validate recovery is possible
          unless can_recover?
            raise RecoveryError, "Workflow cannot be recovered: #{recovery_blockers.join(', ')}"
          end

          case strategy
          when :auto
            auto_recover!
          when :rollback
            rollback_to_safe_state!
          when :reset
            reset_to_step!(target_step)
          when :retry_last
            retry_last_action!
          when :manual
            prepare_manual_recovery!(target_step)
          else
            raise RecoveryError, "Unknown recovery strategy: #{strategy}"
          end
        end

        # Check if workflow can be recovered
        def can_recover?
          recovery_blockers.empty?
        end

        # List reasons why recovery might not be possible
        def recovery_blockers
          blockers = []

          # Check if workflow is in a recoverable state
          if workflow_execution.status == 'completed'
            blockers << "Workflow is already completed"
          end

          # Check for data corruption
          if context_corrupted?
            blockers << "Context data appears corrupted"
          end

          # Check for missing critical data
          missing_data = find_missing_critical_data
          if missing_data.any?
            blockers << "Missing critical data: #{missing_data.join(', ')}"
          end

          # Check workflow definition integrity
          unless workflow_definition_valid?
            blockers << "Workflow definition is invalid or missing"
          end

          blockers
        end

        # Generate recovery plan with multiple options
        def recovery_plan
          return { error: "Cannot generate recovery plan", blockers: recovery_blockers } unless can_recover?

          {
            current_state: analyze_current_state,
            recovery_options: generate_recovery_options,
            recommended_action: recommend_recovery_action,
            rollback_points: identify_rollback_points,
            data_integrity: assess_data_integrity,
            risks: assess_recovery_risks
          }
        end

        # Create a checkpoint before risky operations
        def create_checkpoint(label = nil)
          checkpoint_data = {
            id: SecureRandom.uuid,
            label: label || "Checkpoint #{Time.current.strftime('%Y%m%d_%H%M%S')}",
            workflow_execution_id: workflow_execution.id,
            current_step: workflow_execution.current_step,
            status: workflow_execution.status,
            context_data: deep_dup(workflow_execution.context_data),
            step_history: deep_dup(workflow_execution.step_history),
            created_at: Time.current.iso8601,
            created_by: "recovery_system"
          }

          store_checkpoint(checkpoint_data)
          log_checkpoint_created(checkpoint_data[:id], label)
          
          checkpoint_data[:id]
        end

        # Restore from a specific checkpoint
        def restore_from_checkpoint!(checkpoint_id, force: false)
          checkpoint = load_checkpoint(checkpoint_id)
          raise RecoveryError, "Checkpoint #{checkpoint_id} not found" unless checkpoint

          unless force
            validate_checkpoint_restoration(checkpoint)
          end

          begin
            # Create backup before restoration
            backup_id = create_checkpoint("Before restore from #{checkpoint_id}")

            # Restore workflow state
            workflow_execution.update!(
              current_step: checkpoint['current_step'],
              status: checkpoint['status'],
              context_data: checkpoint['context_data'],
              step_history: checkpoint['step_history']
            )

            log_checkpoint_restored(checkpoint_id)
            
            {
              success: true,
              checkpoint_id: checkpoint_id,
              backup_id: backup_id,
              restored_to_step: checkpoint['current_step']
            }
          rescue => e
            log_recovery_error("Checkpoint restoration failed", e)
            raise RecoveryError, "Failed to restore from checkpoint: #{e.message}"
          end
        end

        # List available recovery checkpoints
        def list_checkpoints
          checkpoints = load_all_checkpoints_for_execution
          
          checkpoints.map do |checkpoint|
            {
              id: checkpoint['id'],
              label: checkpoint['label'],
              step: checkpoint['current_step'],
              created_at: checkpoint['created_at'],
              age: time_ago_in_words(checkpoint['created_at'])
            }
          end
        end

        # Validate workflow execution integrity
        def validate_integrity
          issues = []

          # Check context data integrity
          context_issues = validate_context_integrity
          issues.concat(context_issues)

          # Check step history consistency
          history_issues = validate_history_integrity
          issues.concat(history_issues)

          # Check current step validity
          step_issues = validate_current_step_integrity
          issues.concat(step_issues)

          # Check for orphaned references
          reference_issues = validate_reference_integrity
          issues.concat(reference_issues)

          {
            is_valid: issues.empty?,
            issues: issues,
            severity: assess_issue_severity(issues),
            recommendations: generate_integrity_recommendations(issues)
          }
        end

        # Repair common workflow issues automatically
        def auto_repair!
          repairs_made = []

          # Fix missing or corrupted context data
          context_repairs = repair_context_data
          repairs_made.concat(context_repairs)

          # Fix step history inconsistencies
          history_repairs = repair_step_history
          repairs_made.concat(history_repairs)

          # Correct invalid step states
          step_repairs = repair_step_state
          repairs_made.concat(step_repairs)

          # Clean up orphaned data
          cleanup_repairs = cleanup_orphaned_data
          repairs_made.concat(cleanup_repairs)

          log_auto_repairs(repairs_made)

          {
            success: true,
            repairs_made: repairs_made,
            remaining_issues: validate_integrity[:issues]
          }
        end

        # Export recovery diagnostics for external analysis
        def export_diagnostics(format: :json)
          data = {
            workflow_execution: {
              id: workflow_execution.id,
              workflow_class: workflow_execution.workflow_class,
              current_step: workflow_execution.current_step,
              status: workflow_execution.status,
              context_size: workflow_execution.context_data&.to_s&.bytesize || 0
            },
            recovery_analysis: {
              can_recover: can_recover?,
              blockers: recovery_blockers,
              recovery_plan: recovery_plan
            },
            integrity_check: validate_integrity,
            available_checkpoints: list_checkpoints,
            debug_info: Debugging.debug(workflow_execution).debug_report,
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

        def default_logger
          Rails.logger if defined?(Rails)
        end

        def log_recovery_attempt(strategy, target_step, force)
          logger&.info "Recovery attempt: strategy=#{strategy}, target=#{target_step}, force=#{force}"
        end

        def log_recovery_error(message, error)
          logger&.error "Recovery error: #{message} - #{error.message}"
        end

        def log_checkpoint_created(id, label)
          logger&.info "Checkpoint created: #{id} (#{label})"
        end

        def log_checkpoint_restored(id)
          logger&.info "Restored from checkpoint: #{id}"
        end

        def log_auto_repairs(repairs)
          logger&.info "Auto repairs completed: #{repairs.length} repairs made"
        end

        def auto_recover!
          # Automatic recovery logic based on current state
          if workflow_execution.status == 'failed'
            if can_retry_last_action?
              retry_last_action!
            elsif safe_rollback_point = find_safe_rollback_point
              rollback_to_step!(safe_rollback_point)
            else
              reset_to_initial_state!
            end
          else
            raise RecoveryError, "Auto recovery not applicable for status: #{workflow_execution.status}"
          end
        end

        def rollback_to_safe_state!
          safe_point = find_safe_rollback_point
          raise RecoveryError, "No safe rollback point found" unless safe_point

          rollback_to_step!(safe_point)
        end

        def reset_to_step!(target_step)
          raise RecoveryError, "Target step required for reset" unless target_step

          unless valid_step?(target_step)
            raise RecoveryError, "Invalid target step: #{target_step}"
          end

          # Create checkpoint before reset
          checkpoint_id = create_checkpoint("Before reset to #{target_step}")

          # Reset to target step
          workflow_execution.update!(
            current_step: target_step.to_s,
            status: 'active'
          )

          log_recovery_action("Reset to step #{target_step}")
          
          {
            success: true,
            action: 'reset',
            target_step: target_step,
            checkpoint_id: checkpoint_id
          }
        end

        def retry_last_action!
          history = workflow_execution.step_history || []
          raise RecoveryError, "No action history to retry" if history.empty?

          last_transition = history.last
          from_step = last_transition['from_step']
          
          # Rollback to previous step
          workflow_execution.update!(
            current_step: from_step,
            status: 'active'
          )

          log_recovery_action("Retry last action from #{from_step}")
          
          {
            success: true,
            action: 'retry_last',
            from_step: from_step,
            last_action: last_transition['action']
          }
        end

        def prepare_manual_recovery!(target_step)
          # Prepare system for manual intervention
          checkpoint_id = create_checkpoint("Before manual recovery")
          
          {
            success: true,
            action: 'manual_preparation',
            checkpoint_id: checkpoint_id,
            instructions: generate_manual_recovery_instructions(target_step),
            recovery_plan: recovery_plan
          }
        end

        def context_corrupted?
          context = workflow_execution.context_data
          return true if context.nil?

          # Check for basic corruption indicators
          begin
            JSON.parse(context.to_json) if context.is_a?(Hash)
            false
          rescue JSON::GeneratorError
            true
          rescue => e
            logger&.warn "Context corruption check error: #{e.message}"
            true
          end
        end

        def find_missing_critical_data
          missing = []
          
          # Check for workflowable reference
          unless workflow_execution.workflowable_id && workflow_execution.workflowable_type
            missing << "workflowable reference"
          end

          # Check for workflow class
          unless workflow_execution.workflow_class.present?
            missing << "workflow_class"
          end

          missing
        end

        def workflow_definition_valid?
          return false unless workflow_execution.workflow_class.present?

          begin
            workflow_class = workflow_execution.workflow_class.constantize
            workflow_class.respond_to?(:step_names) && workflow_class.step_names.any?
          rescue NameError
            false
          end
        end

        def analyze_current_state
          {
            step: workflow_execution.current_step,
            status: workflow_execution.status,
            last_updated: workflow_execution.updated_at,
            context_size: workflow_execution.context_data&.to_s&.bytesize || 0,
            history_entries: workflow_execution.step_history&.length || 0
          }
        end

        def generate_recovery_options
          options = []

          if can_retry_last_action?
            options << {
              strategy: :retry_last,
              description: "Retry the last failed action",
              risk: :low,
              estimated_time: "< 1 minute"
            }
          end

          safe_points = identify_rollback_points
          if safe_points.any?
            options << {
              strategy: :rollback,
              description: "Rollback to a safe checkpoint",
              risk: :medium,
              options: safe_points,
              estimated_time: "1-5 minutes"
            }
          end

          options << {
            strategy: :reset,
            description: "Reset to a specific step",
            risk: :high,
            estimated_time: "5-15 minutes"
          }

          options
        end

        def recommend_recovery_action
          if can_retry_last_action?
            :retry_last
          elsif identify_rollback_points.any?
            :rollback
          else
            :manual
          end
        end

        def identify_rollback_points
          history = workflow_execution.step_history || []
          
          # Find steps that are considered "safe" rollback points
          safe_points = []
          
          history.reverse.each_with_index do |transition, index|
            step = transition['to_step']
            
            # Consider a step safe if it's a well-defined checkpoint
            if safe_rollback_step?(step)
              safe_points << {
                step: step,
                timestamp: transition['timestamp'],
                steps_back: index + 1,
                description: describe_rollback_point(step)
              }
            end
          end

          safe_points
        end

        def assess_data_integrity
          {
            context_valid: !context_corrupted?,
            history_consistent: validate_history_integrity.empty?,
            references_valid: validate_reference_integrity.empty?,
            overall_score: calculate_integrity_score
          }
        end

        def assess_recovery_risks
          risks = []
          
          if workflow_execution.context_data&.to_s&.bytesize.to_i > 1.megabyte
            risks << "Large context data may slow recovery"
          end

          if workflow_execution.step_history&.length.to_i > 100
            risks << "Long execution history may complicate rollback"
          end

          risks
        end

        def store_checkpoint(checkpoint_data)
          # In a real implementation, this would store to a persistent location
          # For now, we'll store in the workflow execution context
          checkpoints = workflow_execution.context_data['_checkpoints'] || []
          checkpoints << checkpoint_data
          
          workflow_execution.update!(
            context_data: workflow_execution.context_data.merge('_checkpoints' => checkpoints)
          )
        end

        def load_checkpoint(checkpoint_id)
          checkpoints = workflow_execution.context_data['_checkpoints'] || []
          checkpoints.find { |cp| cp['id'] == checkpoint_id }
        end

        def load_all_checkpoints_for_execution
          workflow_execution.context_data['_checkpoints'] || []
        end

        def validate_checkpoint_restoration(checkpoint)
          # Validate that restoring this checkpoint is safe
          issues = []
          
          current_time = Time.current
          checkpoint_time = Time.parse(checkpoint['created_at'])
          
          if current_time - checkpoint_time > 7.days
            issues << "Checkpoint is older than 7 days"
          end

          if checkpoint['context_data'].nil?
            issues << "Checkpoint has no context data"
          end

          unless issues.empty?
            raise RecoveryError, "Checkpoint validation failed: #{issues.join(', ')}"
          end
        end

        def validate_context_integrity
          issues = []
          context = workflow_execution.context_data

          return ["Context data is missing"] if context.nil?

          # Check for required fields based on current step
          required_fields = determine_required_context_fields
          missing_fields = required_fields - context.keys
          
          missing_fields.each do |field|
            issues << "Missing required context field: #{field}"
          end

          issues
        end

        def validate_history_integrity
          issues = []
          history = workflow_execution.step_history || []

          # Check for gaps in history
          if history.any? && history.first['from_step'] != workflow_definition.class.initial_step.to_s
            issues << "History doesn't start from initial step"
          end

          # Check for invalid transitions
          history.each_with_index do |transition, index|
            next if index == 0
            
            prev_transition = history[index - 1]
            if prev_transition['to_step'] != transition['from_step']
              issues << "History gap between steps #{prev_transition['to_step']} and #{transition['from_step']}"
            end
          end

          issues
        end

        def validate_current_step_integrity
          issues = []
          current_step = workflow_execution.current_step

          unless workflow_definition.class.step_names.include?(current_step.to_sym)
            issues << "Current step '#{current_step}' is not defined in workflow"
          end

          issues
        end

        def validate_reference_integrity
          issues = []

          # Check workflowable reference
          if workflow_execution.workflowable_id && workflow_execution.workflowable_type
            begin
              workflowable = workflow_execution.workflowable
              issues << "Workflowable reference is broken" if workflowable.nil?
            rescue => e
              issues << "Error loading workflowable: #{e.message}"
            end
          end

          issues
        end

        def assess_issue_severity(issues)
          return :none if issues.empty?
          
          critical_keywords = ['corrupted', 'missing', 'broken', 'invalid']
          
          if issues.any? { |issue| critical_keywords.any? { |keyword| issue.downcase.include?(keyword) } }
            :critical
          elsif issues.length > 5
            :high
          elsif issues.length > 2
            :medium
          else
            :low
          end
        end

        def generate_integrity_recommendations(issues)
          recommendations = []
          
          if issues.any? { |i| i.include?('context') }
            recommendations << "Consider resetting context data to a known good state"
          end

          if issues.any? { |i| i.include?('history') }
            recommendations << "Review and possibly rebuild step history"
          end

          if issues.any? { |i| i.include?('reference') }
            recommendations << "Verify and repair object references"
          end

          recommendations
        end

        def repair_context_data
          repairs = []
          context = workflow_execution.context_data || {}

          # Add missing required fields with default values
          required_fields = determine_required_context_fields
          missing_fields = required_fields - context.keys

          missing_fields.each do |field|
            default_value = determine_default_value_for_field(field)
            context[field] = default_value
            repairs << "Added missing context field: #{field}"
          end

          if repairs.any?
            workflow_execution.update!(context_data: context)
          end

          repairs
        end

        def repair_step_history
          repairs = []
          # Implementation would repair history inconsistencies
          repairs
        end

        def repair_step_state
          repairs = []
          
          # Fix invalid current step
          current_step = workflow_execution.current_step
          unless workflow_definition.class.step_names.include?(current_step.to_sym)
            # Reset to initial step
            workflow_execution.update!(current_step: workflow_definition.class.initial_step.to_s)
            repairs << "Reset invalid current step to initial step"
          end

          repairs
        end

        def cleanup_orphaned_data
          repairs = []
          # Implementation would clean up orphaned data
          repairs
        end

        def can_retry_last_action?
          history = workflow_execution.step_history || []
          history.any? && workflow_execution.status == 'failed'
        end

        def find_safe_rollback_point
          identify_rollback_points.first&.dig(:step)
        end

        def rollback_to_step!(step)
          checkpoint_id = create_checkpoint("Before rollback to #{step}")
          
          workflow_execution.update!(
            current_step: step.to_s,
            status: 'active'
          )

          {
            success: true,
            action: 'rollback',
            target_step: step,
            checkpoint_id: checkpoint_id
          }
        end

        def reset_to_initial_state!
          initial_step = workflow_definition.class.initial_step
          reset_to_step!(initial_step)
        end

        def valid_step?(step)
          workflow_definition.class.step_names.include?(step.to_sym)
        end

        def log_recovery_action(message)
          logger&.info "Recovery action: #{message}"
        end

        def generate_manual_recovery_instructions(target_step)
          [
            "1. Review the current workflow state and context data",
            "2. Identify the root cause of the failure",
            "3. Make necessary corrections to the context or external systems",
            target_step ? "4. Consider resetting to step: #{target_step}" : "4. Choose appropriate recovery step",
            "5. Create a checkpoint before making changes",
            "6. Test the recovery in a non-production environment if possible"
          ]
        end

        def safe_rollback_step?(step)
          # Define which steps are considered safe rollback points
          safe_steps = %w[initial_setup documentation_review it_provisioning final_review]
          safe_steps.include?(step)
        end

        def describe_rollback_point(step)
          descriptions = {
            'initial_setup' => 'Beginning of onboarding process',
            'documentation_review' => 'Start of documentation review',
            'it_provisioning' => 'IT setup phase',
            'final_review' => 'Final review stage'
          }
          
          descriptions[step] || "Step: #{step}"
        end

        def calculate_integrity_score
          issues = validate_integrity[:issues]
          max_score = 100
          deduction_per_issue = 10
          
          score = max_score - (issues.length * deduction_per_issue)
          [score, 0].max
        end

        def deep_dup(obj)
          case obj
          when Hash
            obj.each_with_object({}) { |(k, v), h| h[k] = deep_dup(v) }
          when Array
            obj.map { |item| deep_dup(item) }
          else
            obj.dup rescue obj
          end
        end

        def time_ago_in_words(timestamp)
          time = Time.parse(timestamp)
          seconds = Time.current - time
          
          case seconds
          when 0..59
            "#{seconds.to_i} seconds ago"
          when 60..3599
            "#{(seconds / 60).to_i} minutes ago"
          when 3600..86399
            "#{(seconds / 3600).to_i} hours ago"
          else
            "#{(seconds / 86400).to_i} days ago"
          end
        rescue
          "Unknown"
        end

        def determine_required_context_fields
          # This would be customized based on workflow requirements
          %w[workflowable]
        end

        def determine_default_value_for_field(field)
          case field
          when 'workflowable'
            workflow_execution.workflowable
          else
            nil
          end
        end

        def workflow_definition
          @workflow_definition ||= workflow_execution.workflow_definition
        end
      end

      # Class methods for easy access
      def self.recover(workflow_execution, strategy: :auto, **options)
        WorkflowRecovery.new(workflow_execution).recover!(strategy: strategy, **options)
      end

      def self.validate_integrity(workflow_execution)
        WorkflowRecovery.new(workflow_execution).validate_integrity
      end

      def self.create_checkpoint(workflow_execution, label = nil)
        WorkflowRecovery.new(workflow_execution).create_checkpoint(label)
      end

      def self.export_diagnostics(workflow_execution, format: :json)
        WorkflowRecovery.new(workflow_execution).export_diagnostics(format: format)
      end
    end
  end
end