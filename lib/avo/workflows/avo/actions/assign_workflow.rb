# frozen_string_literal: true

module Avo
  module Workflows
    module Avo
      module Actions
        class AssignWorkflow < ::Avo::BaseAction
          self.name = "Assign Workflow"

          def fields
            field :assigned_to_id, as: :select, options: -> {
              # Get user model from configuration
              user_model = ::Avo::Workflows.configuration.user_model
              return {} unless user_model

              # Create options hash from users
              user_model.all.map do |user|
                display_name = user.try(:name) || user.try(:email) || "##{user.id}"
                [display_name, user.id]
              end.to_h
            }, placeholder: "Select a user"

            field :assignment_notes, as: :textarea, placeholder: "Optional notes about this assignment"
          end

          def handle(**args)
            models, fields = args.values_at(:models, :fields)

            assigned_to_id = fields[:assigned_to_id]
            assignment_notes = fields[:assignment_notes]

            if assigned_to_id.blank?
              error "Please select a user to assign the workflow to"
              return
            end

            begin
              user_model = ::Avo::Workflows.configuration.user_model
              assigned_user = user_model.find(assigned_to_id)

              models.each do |workflow_execution|
                additional_context = workflow_execution.context_data || {}
                additional_context[:assignment_notes] = assignment_notes if assignment_notes.present?
                additional_context[:assigned_at] = Time.current
                additional_context[:assigned_by] = current_user_for_workflow&.id

                workflow_execution.update!(
                  assigned_to: assigned_user,
                  context_data: additional_context
                )

                display_name = assigned_user.try(:name) || assigned_user.try(:email) || "##{assigned_user.id}"
                succeed "Successfully assigned workflow to #{display_name}"
              end
            rescue ActiveRecord::RecordNotFound
              error "Selected user not found"
            rescue => e
              error "Error assigning workflow: #{e.message}"
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