# frozen_string_literal: true

module Avo
  module Workflows
    class Registry
      class << self
        def workflows
          @workflows ||= {}
        end

        def register(workflow_class)
          workflows[workflow_class.name] = workflow_class
        end

        def find(workflow_name)
          workflows[workflow_name.to_s]
        end

        def all
          workflows.values
        end

        def workflow_names
          workflows.keys
        end

        def clear!
          @workflows = {}
        end

        # Auto-discover and register workflows
        def auto_discover!
          if defined?(Rails) && Rails.application
            workflow_paths = [
              Rails.application.root.join("app", "avo", "workflows"),
              Rails.application.root.join("app", "workflows")
            ]

            workflow_paths.each do |path|
              next unless Dir.exist?(path)

              Dir.glob(path.join("**", "*.rb")).each do |file|
                begin
                  load file
                rescue LoadError => e
                  Rails.logger.warn "Could not load workflow file #{file}: #{e.message}"
                end
              end
            end
          end

          # Register all classes that inherit from Avo::Workflows::Base
          register_workflow_classes
        end

        def register_workflow_classes
          ObjectSpace.each_object(Class).select do |klass|
            klass < Avo::Workflows::Base && klass != Avo::Workflows::Base && klass.name
          end.each do |workflow_class|
            register(workflow_class) unless workflow_exists?(workflow_class.name)
          end
        end

        # Create execution for a workflow
        def create_execution(workflow_name, workflowable, **options)
          workflow_class = find(workflow_name)
          raise Error, "Workflow '#{workflow_name}' not found" unless workflow_class

          workflow_class.create_execution_for(workflowable, **options)
        end

        # Check if a workflow exists
        def workflow_exists?(workflow_name)
          workflows.key?(workflow_name.to_s)
        end
      end
    end
  end
end