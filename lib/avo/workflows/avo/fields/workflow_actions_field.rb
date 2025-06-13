# frozen_string_literal: true

module Avo
  module Workflows
    module Avo
      module Fields
        class WorkflowActionsField < ::Avo::Fields::BaseField
          self.field_type = "workflow_actions"

          def initialize(id, **args, &block)
            super(id, **args, &block)
            
            @button_style = args.fetch(:button_style, :primary)
            @show_descriptions = args.fetch(:show_descriptions, false)
            @inline = args.fetch(:inline, true)
          end

          def fill_field(model, key, value, params)
            # This field handles actions, not direct model updates
          end

          def value
            return nil unless model.is_a?(WorkflowExecution)

            available_actions = model.available_actions
            return nil if available_actions.empty?

            {
              actions: available_actions.map { |action| format_action(action) },
              button_style: @button_style,
              show_descriptions: @show_descriptions,
              inline: @inline,
              execution_id: model.id
            }
          end

          private

          def format_action(action)
            workflow_class = Registry.find(model.workflow_class)
            step_definition = workflow_class&.workflow_steps&.[](model.current_step.to_sym)
            action_definition = step_definition&.actions&.[](action.to_sym)

            {
              name: action.to_s,
              display_name: action.to_s.humanize,
              description: action_definition&.description,
              requires_confirmation: action_definition&.confirmation_required?,
              color: action_color(action.to_s),
              icon: action_icon(action.to_s)
            }
          end

          def action_color(action_name)
            case action_name.downcase
            when /approve|accept|complete|finish|submit/
              'green'
            when /reject|decline|cancel|abort/
              'red'
            when /review|pending|hold|pause/
              'yellow'
            when /edit|update|modify/
              'blue'
            else
              'gray'
            end
          end

          def action_icon(action_name)
            case action_name.downcase
            when /approve|accept|complete|finish/
              'check'
            when /reject|decline|cancel/
              'x'
            when /submit|send/
              'paper-airplane'
            when /review|view/
              'eye'
            when /edit|update/
              'pencil'
            when /pause|hold/
              'pause'
            when /play|resume/
              'play'
            else
              'cog'
            end
          end
        end
      end
    end
  end
end