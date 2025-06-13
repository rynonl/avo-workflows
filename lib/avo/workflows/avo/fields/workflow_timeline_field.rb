# frozen_string_literal: true

module Avo
  module Workflows
    module Avo
      module Fields
        class WorkflowTimelineField < ::Avo::Fields::BaseField
          self.field_type = "workflow_timeline"

          def initialize(id, **args, &block)
            super(id, **args, &block)
            
            @max_entries = args.fetch(:max_entries, 10)
            @show_timestamps = args.fetch(:show_timestamps, true)
            @compact_view = args.fetch(:compact_view, false)
          end

          def fill_field(model, key, value, params)
            # This field is read-only
          end

          def value
            return nil unless model.is_a?(WorkflowExecution)
            return nil unless model.history_data.present?

            history = model.history_data || []
            limited_history = @max_entries > 0 ? history.last(@max_entries) : history

            {
              timeline_entries: limited_history.map { |entry| format_timeline_entry(entry) },
              show_timestamps: @show_timestamps,
              compact_view: @compact_view,
              total_entries: history.length,
              showing_entries: limited_history.length
            }
          end

          private

          def format_timeline_entry(entry)
            {
              type: entry['type'] || 'general',
              icon: timeline_icon_name(entry['type']),
              color: timeline_color(entry['type']),
              title: timeline_title(entry),
              description: timeline_description(entry),
              timestamp: entry['timestamp'] ? Time.parse(entry['timestamp']) : nil,
              user: entry['performed_by'] || entry['assigned_by'],
              metadata: entry.except('type', 'timestamp', 'performed_by', 'assigned_by')
            }
          end

          def timeline_icon_name(type)
            case type
            when 'step_change'
              'arrow-right'
            when 'assignment'
              'user'
            when 'action'
              'lightning-bolt'
            when 'status_change'
              'refresh'
            when 'comment', 'note'
              'chat'
            else
              'clock'
            end
          end

          def timeline_color(type)
            case type
            when 'step_change'
              'blue'
            when 'assignment'
              'green'
            when 'action'
              'purple'
            when 'status_change'
              'yellow'
            when 'error', 'failure'
              'red'
            else
              'gray'
            end
          end

          def timeline_title(entry)
            case entry['type']
            when 'step_change'
              from = entry['from_step'] || 'initial'
              to = entry['to_step']
              "Moved to #{to.humanize}"
            when 'assignment'
              assigned_to = entry['assigned_to'] || 'Unknown'
              "Assigned to #{assigned_to}"
            when 'action'
              action = entry['action'] || 'Unknown Action'
              "#{action.humanize} performed"
            when 'status_change'
              to_status = entry['to_status'] || 'Unknown'
              "Status changed to #{to_status.humanize}"
            when 'comment', 'note'
              "Comment added"
            else
              entry['title'] || 'Workflow event'
            end
          end

          def timeline_description(entry)
            case entry['type']
            when 'step_change'
              from = entry['from_step'] || 'initial'
              "Previous step: #{from.humanize}"
            when 'assignment'
              entry['assignment_notes'] || entry['notes']
            when 'action'
              entry['notes'] || entry['description']
            when 'status_change'
              from = entry['from_status']
              from ? "Previous status: #{from.humanize}" : nil
            else
              entry['description'] || entry['message']
            end
          end
        end
      end
    end
  end
end