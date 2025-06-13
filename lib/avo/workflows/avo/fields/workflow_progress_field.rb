# frozen_string_literal: true

module Avo
  module Workflows
    module Avo
      module Fields
        class WorkflowProgressField < ::Avo::Fields::BaseField
          self.field_type = "workflow_progress"

          def initialize(id, **args, &block)
            super(id, **args, &block)
            
            @show_percentage = args.fetch(:show_percentage, true)
            @show_step_names = args.fetch(:show_step_names, true)
            @color_scheme = args.fetch(:color_scheme, :default)
          end

          def fill_field(model, key, value, params)
            # This field is read-only, so we don't need to handle updates
          end

          def value
            return nil unless model.is_a?(WorkflowExecution)

            workflow_class = Registry.find(model.workflow_class)
            return nil unless workflow_class

            calculate_progress(model, workflow_class)
          end

          private

          def calculate_progress(execution, workflow_class)
            steps = workflow_class.workflow_steps.keys
            return { percentage: 0, current_step: nil, total_steps: 0 } if steps.empty?

            current_step_index = steps.index(execution.current_step.to_sym)
            return { percentage: 0, current_step: execution.current_step, total_steps: steps.length } unless current_step_index

            # Calculate percentage based on current step position
            percentage = ((current_step_index + 1).to_f / steps.length * 100).round

            # Check if workflow is completed
            if execution.status == 'completed'
              percentage = 100
            elsif execution.status == 'failed'
              percentage = -1 # Special indicator for failed state
            end

            {
              percentage: percentage,
              current_step: execution.current_step,
              current_step_index: current_step_index,
              total_steps: steps.length,
              steps: steps.map(&:to_s),
              status: execution.status,
              show_percentage: @show_percentage,
              show_step_names: @show_step_names,
              color_scheme: @color_scheme
            }
          end
        end
      end
    end
  end
end