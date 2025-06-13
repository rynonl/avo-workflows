# frozen_string_literal: true

module Avo
  module Workflows
    module Avo
      module Actions
        class PerformWorkflowAction < ::Avo::BaseAction
          self.name = "Perform Workflow Action"
          self.visible = -> { view == :show }

          def fields
            field :action_name, as: :select, options: -> {
              return {} unless resource.model

              available_actions = resource.model.available_actions
              available_actions.map { |action| [action.to_s.humanize, action.to_s] }.to_h
            }, placeholder: "Select an action"

            field :notes, as: :textarea, placeholder: "Optional notes about this action"
          end

          def handle(**args)
            models, fields = args.values_at(:models, :fields)

            action_name = fields[:action_name]
            notes = fields[:notes]

            if action_name.blank?
              error "Please select an action to perform"
              return
            end

            models.each do |workflow_execution|
              begin
                additional_context = {}
                additional_context[:notes] = notes if notes.present?
                additional_context[:performed_by] = current_user.id if respond_to?(:current_user) && current_user

                success = workflow_execution.perform_action(
                  action_name.to_sym,
                  user: current_user_for_workflow,
                  additional_context: additional_context
                )

                if success
                  succeed "Successfully performed '#{action_name.humanize}' on #{workflow_execution.workflow_class}"
                else
                  error "Failed to perform '#{action_name.humanize}': #{workflow_execution.errors.full_messages.join(', ')}"
                end
              rescue => e
                error "Error performing action: #{e.message}"
              end
            end
          end

          private

          def current_user_for_workflow
            if respond_to?(:current_user)
              current_user
            elsif respond_to?(:context) && context[:current_user]
              context[:current_user]
            else
              nil
            end
          end
        end
      end
    end
  end
end