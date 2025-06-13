# frozen_string_literal: true

module Avo
  module Workflows
    module Avo
      module Components
        class WorkflowVisualizer < ViewComponent::Base
          def initialize(workflow_execution:, **options)
            @workflow_execution = workflow_execution
            @show_descriptions = options.fetch(:show_descriptions, false)
            @orientation = options.fetch(:orientation, :horizontal) # :horizontal or :vertical
            @size = options.fetch(:size, :medium) # :small, :medium, :large
            @interactive = options.fetch(:interactive, false)
          end

          private

          attr_reader :workflow_execution, :show_descriptions, :orientation, :size, :interactive

          def workflow_class
            @workflow_class ||= Registry.find(workflow_execution.workflow_class)
          end

          def workflow_steps
            return [] unless workflow_class
            
            @workflow_steps ||= workflow_class.workflow_steps.keys.map(&:to_s)
          end

          def current_step_index
            @current_step_index ||= workflow_steps.index(workflow_execution.current_step.to_s) || 0
          end

          def step_status(step, index)
            case
            when index < current_step_index
              'completed'
            when index == current_step_index
              case workflow_execution.status
              when 'completed'
                'completed'
              when 'failed'
                'failed'
              when 'paused'
                'paused'
              else
                'current'
              end
            else
              'pending'
            end
          end

          def step_classes(step, index)
            base_classes = ["workflow-step"]
            base_classes << "workflow-step--#{step_status(step, index)}"
            base_classes << "workflow-step--#{size}"
            base_classes << "workflow-step--interactive" if interactive
            base_classes.join(" ")
          end

          def connector_classes(index)
            base_classes = ["workflow-connector"]
            base_classes << "workflow-connector--#{size}"
            
            if index < current_step_index
              base_classes << "workflow-connector--completed"
            else
              base_classes << "workflow-connector--pending"
            end
            
            base_classes.join(" ")
          end

          def step_icon(step, status)
            case status
            when 'completed'
              'check-circle'
            when 'current'
              'play-circle'
            when 'failed'
              'x-circle'
            when 'paused'
              'pause-circle'
            else
              'circle'
            end
          end

          def step_color(status)
            case status
            when 'completed'
              'text-green-600 bg-green-50 border-green-200'
            when 'current'
              'text-blue-600 bg-blue-50 border-blue-200'
            when 'failed'
              'text-red-600 bg-red-50 border-red-200'
            when 'paused'
              'text-yellow-600 bg-yellow-50 border-yellow-200'
            else
              'text-gray-400 bg-gray-50 border-gray-200'
            end
          end

          def container_classes
            base_classes = ["workflow-visualizer"]
            base_classes << "workflow-visualizer--#{orientation}"
            base_classes << "workflow-visualizer--#{size}"
            base_classes.join(" ")
          end

          def step_description(step)
            return nil unless show_descriptions && workflow_class
            
            step_definition = workflow_class.workflow_steps[step.to_sym]
            step_definition&.description
          end

          def step_actions(step)
            return [] unless workflow_class
            
            step_definition = workflow_class.workflow_steps[step.to_sym]
            return [] unless step_definition
            
            step_definition.actions.keys.map(&:to_s)
          end

          def progress_percentage
            return 100 if workflow_execution.status == 'completed'
            return 0 if workflow_steps.empty?
            
            ((current_step_index + 1).to_f / workflow_steps.length * 100).round
          end
        end
      end
    end
  end
end