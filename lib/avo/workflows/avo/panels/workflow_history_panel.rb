# frozen_string_literal: true

module Avo
  module Workflows
    module Avo
      module Panels
        class WorkflowHistoryPanel < ::Avo::Panels::BasePanel
          self.name = "Workflow History"
          self.collapsible = true

          def initialize(record:, **kwargs)
            @record = record
            super(**kwargs)
          end

          def visible?
            @record.is_a?(WorkflowExecution) && @record.history_data.present?
          end

          def body
            return nil unless visible?

            history = @record.history_data || []
            return "<p class='text-sm text-gray-500'>No history available</p>".html_safe if history.empty?

            build_history_timeline(history)
          end

          private

          def build_history_timeline(history)
            content = []
            content << "<div class='flow-root'>"
            content << "<ul class='-mb-8'>"

            history.reverse.each_with_index do |entry, index|
              is_last = index == history.length - 1
              
              content << "<li>"
              content << "<div class='relative pb-8'>" unless is_last
              content << "<div class='relative'>" if is_last

              # Timeline line
              unless is_last
                content << "<span class='absolute top-4 left-4 -ml-px h-full w-0.5 bg-gray-200' aria-hidden='true'></span>"
              end

              # Timeline dot
              content << "<div class='relative flex space-x-3'>"
              content << "<div>"
              content << timeline_icon(entry)
              content << "</div>"

              # Content
              content << "<div class='min-w-0 flex-1 pt-1.5 flex justify-between space-x-4'>"
              content << "<div>"
              content << "<p class='text-sm text-gray-500'>#{format_history_entry(entry)}</p>"
              content << "</div>"
              content << "<div class='text-right text-sm whitespace-nowrap text-gray-500'>"
              
              if entry['timestamp']
                timestamp = Time.parse(entry['timestamp'])
                content << "<time datetime='#{timestamp.iso8601}'>#{timestamp.strftime('%b %d, %Y %I:%M %p')}</time>"
              end
              
              content << "</div>"
              content << "</div>"
              content << "</div>"
              content << "</div>"
              content << "</li>"
            end

            content << "</ul>"
            content << "</div>"
            
            content.join.html_safe
          end

          def timeline_icon(entry)
            case entry['type']
            when 'step_change'
              "<span class='h-8 w-8 rounded-full bg-blue-500 flex items-center justify-center ring-8 ring-white'>" \
              "<svg class='h-4 w-4 text-white' fill='currentColor' viewBox='0 0 20 20'>" \
              "<path fill-rule='evenodd' d='M7.293 14.707a1 1 0 010-1.414L10.586 10 7.293 6.707a1 1 0 011.414-1.414l4 4a1 1 0 010 1.414l-4 4a1 1 0 01-1.414 0z' clip-rule='evenodd'></path>" \
              "</svg></span>"
            when 'assignment'
              "<span class='h-8 w-8 rounded-full bg-green-500 flex items-center justify-center ring-8 ring-white'>" \
              "<svg class='h-4 w-4 text-white' fill='currentColor' viewBox='0 0 20 20'>" \
              "<path d='M13 6a3 3 0 11-6 0 3 3 0 016 0zM18 8a2 2 0 11-4 0 2 2 0 014 0zM14 15a4 4 0 00-8 0v3h8v-3z'></path>" \
              "</svg></span>"
            when 'action'
              "<span class='h-8 w-8 rounded-full bg-purple-500 flex items-center justify-center ring-8 ring-white'>" \
              "<svg class='h-4 w-4 text-white' fill='currentColor' viewBox='0 0 20 20'>" \
              "<path fill-rule='evenodd' d='M10 18a8 8 0 100-16 8 8 0 000 16zm3.707-9.293a1 1 0 00-1.414-1.414L9 10.586 7.707 9.293a1 1 0 00-1.414 1.414l2 2a1 1 0 001.414 0l4-4z' clip-rule='evenodd'></path>" \
              "</svg></span>"
            else
              "<span class='h-8 w-8 rounded-full bg-gray-400 flex items-center justify-center ring-8 ring-white'>" \
              "<svg class='h-4 w-4 text-white' fill='currentColor' viewBox='0 0 20 20'>" \
              "<path fill-rule='evenodd' d='M18 10a8 8 0 11-16 0 8 8 0 0116 0zm-7-4a1 1 0 11-2 0 1 1 0 012 0zM9 9a1 1 0 000 2v3a1 1 0 001 1h1a1 1 0 100-2v-3a1 1 0 00-1-1H9z' clip-rule='evenodd'></path>" \
              "</svg></span>"
            end
          end

          def format_history_entry(entry)
            case entry['type']
            when 'step_change'
              from_step = entry['from_step'] || 'initial'
              to_step = entry['to_step']
              "Moved from <strong>#{from_step.humanize}</strong> to <strong>#{to_step.humanize}</strong>"
            when 'assignment'
              user_info = entry['assigned_to'] || 'Unknown User'
              "Assigned to <strong>#{user_info}</strong>"
            when 'action'
              action_name = entry['action'] || 'Unknown Action'
              user_info = entry['performed_by'] || 'System'
              "Action <strong>#{action_name.humanize}</strong> performed by #{user_info}"
            when 'status_change'
              from_status = entry['from_status'] || 'unknown'
              to_status = entry['to_status'] || 'unknown'
              "Status changed from <strong>#{from_status.humanize}</strong> to <strong>#{to_status.humanize}</strong>"
            else
              entry['message'] || 'Workflow event occurred'
            end.html_safe
          end
        end
      end
    end
  end
end