# frozen_string_literal: true

module Avo
  module Workflows
    module Avo
      class WorkflowResource < ::Avo::BaseResource
        self.title = :id
        self.includes = [:workflowable, :assigned_to]
        self.model_class = ::Avo::Workflows::WorkflowExecution

        def fields
          field :id, as: :id
          
          field :workflow_class, as: :text, readonly: true do |model|
            model.workflow_class
          end
          
          field :workflowable, as: :belongs_to, polymorphic_as: :workflowable do |model|
            if model.workflowable
              "#{model.workflowable_type} ##{model.workflowable_id}"
            else
              "No workflowable"
            end
          end
          
          field :current_step, as: :badge do |model|
            {
              value: model.current_step.to_s.humanize,
              color: step_color(model.current_step, model.workflow_definition)
            }
          end
          
          field :status, as: :badge do |model|
            {
              value: model.status.humanize,
              color: status_color(model.status)
            }
          end
          
          field :assigned_to, as: :belongs_to, polymorphic_as: :assigned_to, optional: true
          
          field :context_data, as: :code, language: :json, hide_on: [:index] do |model|
            JSON.pretty_generate(model.context_data || {})
          end
          
          field :step_history, as: :code, language: :json, hide_on: [:index, :edit] do |model|
            JSON.pretty_generate(model.step_history || [])
          end
          
          field :created_at, as: :date_time, readonly: true
          field :updated_at, as: :date_time, readonly: true
        end

        def filters
          filter ::Avo::Workflows::Avo::Filters::WorkflowClassFilter
          filter ::Avo::Workflows::Avo::Filters::StatusFilter
          filter ::Avo::Workflows::Avo::Filters::CurrentStepFilter
        end

        def actions
          action ::Avo::Workflows::Avo::Actions::PerformWorkflowAction
          action ::Avo::Workflows::Avo::Actions::AssignWorkflow
        end

        def panels
          panel ::Avo::Workflows::Avo::Panels::WorkflowStepPanel
          panel ::Avo::Workflows::Avo::Panels::WorkflowHistoryPanel
          panel ::Avo::Workflows::Avo::Panels::WorkflowContextPanel
        end

        private

        def step_color(step, workflow_definition)
          return :gray unless workflow_definition

          if workflow_definition.final_step?(step.to_sym)
            :green
          elsif step.to_s.include?('pending') || step.to_s.include?('review')
            :yellow
          elsif step.to_s.include?('draft') || step.to_s.include?('new')
            :blue
          elsif step.to_s.include?('rejected') || step.to_s.include?('failed')
            :red
          else
            :gray
          end
        end

        def status_color(status)
          case status.to_s
          when 'active'
            :blue
          when 'completed'
            :green
          when 'failed'
            :red
          when 'paused'
            :yellow
          else
            :gray
          end
        end
      end
    end
  end
end