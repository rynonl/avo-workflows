# frozen_string_literal: true

module Avo
  module Workflows
    module Avo
      module Panels
        class WorkflowContextPanel < ::Avo::Panels::BasePanel
          self.name = "Workflow Context"
          self.collapsible = true

          def initialize(record:, **kwargs)
            @record = record
            super(**kwargs)
          end

          def visible?
            @record.is_a?(WorkflowExecution) && @record.context_data.present?
          end

          def body
            return nil unless visible?

            context = @record.context_data || {}
            return "<p class='text-sm text-gray-500'>No context data available</p>".html_safe if context.empty?

            build_context_display(context)
          end

          private

          def build_context_display(context)
            content = []
            content << "<div class='space-y-4'>"

            # System context (special handling)
            system_keys = %w[assigned_at assigned_by performed_by assignment_notes notes]
            user_context = context.except(*system_keys)
            
            # User/business context first
            unless user_context.empty?
              content << "<div>"
              content << "<h4 class='text-sm font-medium text-gray-900 mb-2'>Business Context</h4>"
              content << "<dl class='grid grid-cols-1 gap-x-4 gap-y-2 sm:grid-cols-2'>"
              
              user_context.each do |key, value|
                content << "<div>"
                content << "<dt class='text-sm font-medium text-gray-500'>#{key.to_s.humanize}</dt>"
                content << "<dd class='text-sm text-gray-900'>#{format_context_value(value)}</dd>"
                content << "</div>"
              end
              
              content << "</dl>"
              content << "</div>"
            end

            # System context (assignments, notes, etc.)
            system_context = context.slice(*system_keys).compact
            unless system_context.empty?
              content << "<div>"
              content << "<h4 class='text-sm font-medium text-gray-900 mb-2'>System Context</h4>"
              content << "<dl class='grid grid-cols-1 gap-x-4 gap-y-2'>"
              
              system_context.each do |key, value|
                content << "<div>"
                content << "<dt class='text-sm font-medium text-gray-500'>#{key.to_s.humanize}</dt>"
                content << "<dd class='text-sm text-gray-900'>#{format_context_value(value)}</dd>"
                content << "</div>"
              end
              
              content << "</dl>"
              content << "</div>"
            end

            content << "</div>"
            content.join.html_safe
          end

          def format_context_value(value)
            case value
            when Hash
              # For nested objects, show as formatted JSON
              content = "<pre class='text-xs bg-gray-50 p-2 rounded border overflow-auto max-h-32'>"
              content += JSON.pretty_generate(value)
              content += "</pre>"
              content.html_safe
            when Array
              if value.all? { |v| v.is_a?(String) || v.is_a?(Numeric) }
                # Simple array of primitives
                value.join(', ')
              else
                # Complex array, show as JSON
                content = "<pre class='text-xs bg-gray-50 p-2 rounded border overflow-auto max-h-32'>"
                content += JSON.pretty_generate(value)
                content += "</pre>"
                content.html_safe
              end
            when String
              if value.length > 100
                # Long text, show in expandable format
                content = "<div class='text-sm'>"
                content += "<p class='truncate'>#{value[0..100]}...</p>"
                content += "<details class='mt-1'>"
                content += "<summary class='text-xs text-blue-600 cursor-pointer'>Show full text</summary>"
                content += "<p class='mt-2 text-xs bg-gray-50 p-2 rounded border'>#{value}</p>"
                content += "</details>"
                content += "</div>"
                content.html_safe
              else
                value.to_s
              end
            when Time, DateTime
              value.strftime('%B %d, %Y at %I:%M %p')
            when Date
              value.strftime('%B %d, %Y')
            when TrueClass, FalseClass
              content = "<span class='inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium "
              content += value ? "bg-green-100 text-green-800'>Yes" : "bg-red-100 text-red-800'>No"
              content += "</span>"
              content.html_safe
            when Numeric
              value.to_s
            when NilClass
              "<span class='text-gray-400 italic'>nil</span>".html_safe
            else
              value.to_s
            end
          end
        end
      end
    end
  end
end