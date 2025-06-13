# frozen_string_literal: true

module Avo
  module Workflows
    module Avo
      module Panels
        class WorkflowStepPanel < ::Avo::Panels::BasePanel
          self.name = "Current Step Details"
          self.collapsible = false

          def initialize(record:, **kwargs)
            @record = record
            super(**kwargs)
          end

          def visible?
            @record.is_a?(WorkflowExecution) && @record.current_step.present?
          end

          def title
            "Step: #{@record.current_step.humanize}"
          end

          def body
            return nil unless visible?

            workflow_class = Registry.find(@record.workflow_class)
            return "Workflow class not found" unless workflow_class

            step_definition = workflow_class.workflow_steps[@record.current_step.to_sym]
            return "Step definition not found" unless step_definition

            build_step_content(step_definition)
          end

          private

          def build_step_content(step_definition)
            content = []
            
            # Step description
            if step_definition.description.present?
              content << "<div class='mb-4'>"
              content << "<h4 class='text-sm font-medium text-gray-900 mb-2'>Description</h4>"
              content << "<p class='text-sm text-gray-600'>#{step_definition.description}</p>"
              content << "</div>"
            end

            # Available actions
            available_actions = @record.available_actions
            if available_actions.any?
              content << "<div class='mb-4'>"
              content << "<h4 class='text-sm font-medium text-gray-900 mb-2'>Available Actions</h4>"
              content << "<div class='flex flex-wrap gap-2'>"
              available_actions.each do |action|
                content << "<span class='inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-blue-100 text-blue-800'>#{action.to_s.humanize}</span>"
              end
              content << "</div>"
              content << "</div>"
            end

            # Step requirements
            if step_definition.requirements.any?
              content << "<div class='mb-4'>"
              content << "<h4 class='text-sm font-medium text-gray-900 mb-2'>Requirements</h4>"
              content << "<ul class='text-sm text-gray-600 list-disc list-inside'>"
              step_definition.requirements.each do |requirement|
                content << "<li>#{requirement}</li>"
              end
              content << "</ul>"
              content << "</div>"
            end

            # Assignment info
            if @record.assigned_to.present?
              content << "<div class='mb-4'>"
              content << "<h4 class='text-sm font-medium text-gray-900 mb-2'>Assigned To</h4>"
              assigned_name = @record.assigned_to.try(:name) || @record.assigned_to.try(:email) || "##{@record.assigned_to.id}"
              content << "<p class='text-sm text-gray-600'>#{assigned_name}</p>"
              
              if @record.context_data&.dig('assigned_at')
                assigned_at = Time.parse(@record.context_data['assigned_at'])
                content << "<p class='text-xs text-gray-500'>Assigned #{assigned_at.strftime('%B %d, %Y at %I:%M %p')}</p>"
              end
              content << "</div>"
            end

            content.join.html_safe
          end
        end
      end
    end
  end
end