# frozen_string_literal: true

module Avo
  module Workflows
    module Avo
      module Filters
        class WorkflowClassFilter < ::Avo::Filters::SelectFilter
          self.name = "Workflow Type"

          def apply(request, query, values)
            return query if values.empty?

            query.where(workflow_class: values)
          end

          def options
            # Get all registered workflow classes
            Registry.workflow_names.map do |workflow_name|
              [workflow_name.humanize, workflow_name]
            end.to_h
          end

          def default
            {}
          end
        end
      end
    end
  end
end