# frozen_string_literal: true

module Avo
  module Workflows
    module Avo
      module Filters
        class CurrentStepFilter < ::Avo::Filters::SelectFilter
          self.name = "Current Step"

          def apply(request, query, values)
            return query if values.empty?

            query.where(current_step: values)
          end

          def options
            # Get all unique current steps from existing executions
            steps = WorkflowExecution.distinct.pluck(:current_step).compact
            steps.map { |step| [step.humanize, step] }.to_h
          end

          def default
            {}
          end
        end
      end
    end
  end
end