# frozen_string_literal: true

module Avo
  module Workflows
    module Avo
      module Filters
        class StatusFilter < ::Avo::Filters::SelectFilter
          self.name = "Status"

          def apply(request, query, values)
            return query if values.empty?

            query.where(status: values)
          end

          def options
            {
              'Active' => 'active',
              'Completed' => 'completed',
              'Failed' => 'failed',
              'Paused' => 'paused'
            }
          end

          def default
            {}
          end
        end
      end
    end
  end
end