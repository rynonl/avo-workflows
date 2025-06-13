# frozen_string_literal: true

require 'rails/generators'

module AvoWorkflows
  module Generators
    class WorkflowGenerator < Rails::Generators::NamedBase
      source_root File.expand_path('templates', __dir__)
      desc 'Generate a new Avo workflow'

      argument :steps, type: :array, default: [], banner: "step1 step2 step3"

      def create_workflow_file
        template 'workflow.rb.erb', "app/avo/workflows/#{file_name}.rb"
      end

      def create_workflow_spec
        template 'workflow_spec.rb.erb', "spec/avo/workflows/#{file_name}_spec.rb" if defined?(RSpec)
      end

      private

      def workflow_steps
        return default_steps if steps.empty?
        steps.map(&:underscore)
      end

      def default_steps
        %w[draft pending_review approved]
      end

      def workflow_class_name
        "#{class_name}Workflow"
      end
    end
  end
end