# frozen_string_literal: true

module Avo
  module Workflows
    module Avo
      module Actions
        # Enhanced workflow action that supports forms for data collection
        class WorkflowActionWithForm < ::Avo::BaseAction
          include Avo::Workflows::ActionMethods

          attr_accessor :workflow_action_name, :form_class

          def initialize(workflow_action_name:, form_class: nil, **options)
            @workflow_action_name = workflow_action_name
            @form_class = form_class
            super(**options)
            
            setup_action_fields if form_class
          end

          # Dynamically set up fields based on form class
          def setup_action_fields
            return unless form_class&.respond_to?(:field_definitions)

            form_class.field_definitions.each do |field_def|
              add_field_to_action(field_def)
            end
          end

          def handle(**args)
            models = args[:models] || [args[:model]].compact
            fields_data = args[:fields] || {}

            results = []
            models.each do |model|
              result = perform_workflow_action_with_form(
                model: model,
                action: workflow_action_name,
                form_data: fields_data,
                user: args[:current_user]
              )
              results << result
            end

            if results.all?(&:success?)
              if models.size == 1
                succeed "#{workflow_action_name.to_s.humanize} completed successfully"
              else
                succeed "#{workflow_action_name.to_s.humanize} completed for #{models.size} items"
              end
            else
              failed_count = results.count { |r| !r.success? }
              if models.size == 1
                error results.first.error_message
              else
                error "#{failed_count} of #{models.size} actions failed"
              end
            end
          end

          # Check if action should be visible for a resource
          def visible?
            return false unless super
            return false unless resource&.workflow_execution

            # Check if the workflow action is available
            execution = resource.workflow_execution
            execution.available_actions.include?(workflow_action_name.to_sym)
          end

          private

          def perform_workflow_action_with_form(model:, action:, form_data:, user:)
            workflow_execution = model.workflow_execution
            return ActionResult.error("No workflow execution found") unless workflow_execution

            # Create form instance with data
            form_instance = nil
            if form_class
              form_instance = form_class.new(
                workflow_execution: workflow_execution,
                current_user: user,
                action_name: action,
                **form_data
              )

              # Validate form data
              unless form_instance.valid?
                return ActionResult.error("Form validation failed: #{form_instance.errors.full_messages.join(', ')}")
              end
            end

            # Perform the workflow action with form context
            begin
              context_data = form_instance&.to_context || {}
              
              workflow_execution.perform_action(
                action,
                user: user,
                context: context_data
              )

              ActionResult.success("Action completed successfully")
            rescue Avo::Workflows::Errors::WorkflowError => e
              ActionResult.error(e.message)
            rescue => e
              ActionResult.error("Unexpected error: #{e.message}")
            end
          end

          def add_field_to_action(field_def)
            field_name = field_def[:name]
            field_type = avo_field_type(field_def[:type])
            field_options = field_def[:options] || {}

            # Create the field
            case field_type
            when :text
              field field_name, as: :text, **field_options
            when :textarea
              field field_name, as: :textarea, **field_options
            when :boolean
              field field_name, as: :boolean_group, **field_options
            when :select
              options = field_options[:options] || []
              if options.is_a?(Array)
                options_hash = options.each_with_object({}) { |opt, hash| hash[opt.humanize] = opt }
              else
                options_hash = options
              end
              field field_name, as: :select, options: options_hash, **field_options.except(:options)
            when :date
              field field_name, as: :date, **field_options
            when :datetime
              field field_name, as: :date_time, **field_options
            when :number
              field field_name, as: :number, **field_options
            when :hidden
              field field_name, as: :hidden, **field_options
            else
              field field_name, as: :text, **field_options
            end
          end

          def avo_field_type(form_field_type)
            case form_field_type
            when :textarea then :textarea
            when :boolean then :boolean
            when :select then :select
            when :date then :date
            when :datetime then :datetime
            when :number, :integer then :number
            when :hidden then :hidden
            else :text
            end
          end

          # Helper class for action results
          class ActionResult
            attr_reader :success, :error_message

            def initialize(success:, error_message: nil)
              @success = success
              @error_message = error_message
            end

            def success?
              @success
            end

            def self.success(message = nil)
              new(success: true)
            end

            def self.error(message)
              new(success: false, error_message: message)
            end
          end
        end

        # Factory for creating workflow actions with forms
        class WorkflowActionFactory
          def self.create_action(workflow_class, action_name, options = {})
            # Get form class if registered
            form_class = workflow_class.form_for_action(action_name) if workflow_class.respond_to?(:form_for_action)
            
            # Create action class
            action_class = Class.new(WorkflowActionWithForm) do
              self.name = options[:name] || action_name.to_s.humanize
              self.message = options[:message] || "#{action_name.to_s.humanize} completed"
              self.confirm_button_label = options[:confirm_label] || "Confirm"
              
              if options[:dangerous]
                self.confirm_text = options[:confirm_text] || "Are you sure you want to #{action_name.to_s.humanize.downcase}?"
              end

              define_method :initialize do |**args|
                super(
                  workflow_action_name: action_name,
                  form_class: form_class,
                  **args
                )
              end
            end

            action_class
          end
        end
      end
    end
  end
end