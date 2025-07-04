# frozen_string_literal: true

module Avo
  module Workflows
    module Forms
      # Automatic form generation from workflow step panel definitions
      #
      # This class creates dynamic form classes based on the panel fields defined
      # in workflow steps using the new integrated DSL. It bridges the gap between
      # the step-form DSL and the existing forms system.
      #
      # Usage:
      #   form_class = AutoGeneratedForm.for_step(MyWorkflow, :draft)
      #   form_instance = form_class.new(title: 'Test', content: 'Content')
      #   form_instance.valid? #=> true
      #   form_instance.to_context #=> { title: 'Test', content: 'Content' }
      class AutoGeneratedForm
        class << self
          # Creates a dynamic form class for a specific workflow step
          #
          # @param workflow_class [Class] the workflow class containing the step
          # @param step_name [Symbol, String] the step name to generate form for
          # @return [Class, nil] dynamic form class or nil if no panel fields
          # @example
          #   form_class = AutoGeneratedForm.for_step(DocumentWorkflow, :draft)
          #   form_instance = form_class.new(title: 'My Document')
          def for_step(workflow_class, step_name)
            step_def = workflow_class.find_step(step_name.to_sym)
            return nil unless step_def&.panel_fields&.any?

            # Create a dynamic form class that extends the base form
            form_class = Class.new(Base) do
              # Reset field_definitions for this specific class to avoid sharing
              self.field_definitions = []
              
              # Set form metadata from step definition
              title step_def.description || step_name.to_s.humanize
              description "Auto-generated form for #{workflow_class.name} #{step_name} step"

              # Add all panel fields to the form
              step_def.panel_fields.each do |field_def|
                AutoGeneratedForm.add_panel_field_to_form(self, field_def)
              end

              # Store reference to the original step definition
              define_singleton_method :step_definition do
                step_def
              end

              # Store reference to the workflow class
              define_singleton_method :workflow_class do
                workflow_class
              end

              # Store the step name
              define_singleton_method :step_name do
                step_name.to_sym
              end

              # Generate a meaningful class name for debugging
              define_singleton_method :name do
                "#{workflow_class.name}#{step_name.to_s.camelize}Form"
              end

              # Override to_context to include all field values
              define_method :to_context do
                step_def.panel_fields.each_with_object({}) do |field_def, context|
                  field_name = field_def[:name]
                  if respond_to?(field_name)
                    field_value = send(field_name)
                    # Include field if it has a value (including false) or if include_blank is specified
                    if !field_value.nil? && (field_value.present? || field_value == false || field_def[:options][:include_blank])
                      context[field_name] = field_value
                    end
                  end
                end
              end
            end

            form_class
          end

          # Creates form classes for all steps in a workflow that have panels
          #
          # @param workflow_class [Class] the workflow class
          # @return [Hash<Symbol, Class>] hash of step names to form classes
          # @example
          #   forms = AutoGeneratedForm.for_workflow(DocumentWorkflow)
          #   forms[:draft] #=> DocumentWorkflowDraftForm class
          def for_workflow(workflow_class)
            forms = {}
            
            workflow_class.step_names.each do |step_name|
              form_class = for_step(workflow_class, step_name)
              forms[step_name] = form_class if form_class
            end

            forms
          end

          # Adds a panel field definition to the form class being built
          #
          # @param form_class [Class] the form class being built
          # @param field_def [Hash] field definition from panel
          # @return [void]
          def add_panel_field_to_form(form_class, field_def)
            field_name = field_def[:name]
            field_type = field_def[:type]
            field_options = field_def[:options] || {}

            # Map panel field types to form field types
            mapped_type = map_panel_field_type(field_type)
            
            # Convert options to form field format
            form_options = convert_panel_options_to_form_options(field_options, field_type)

            # Add the field to the form using the standard DSL
            form_class.field field_name, as: mapped_type, **form_options
          end

          private

          # Maps panel field types to form field types
          #
          # @param panel_type [Symbol] the panel field type
          # @return [Symbol] the corresponding form field type
          def map_panel_field_type(panel_type)
            case panel_type
            when :text then :text
            when :textarea then :textarea
            when :boolean then :boolean
            when :select then :select
            when :date then :date
            when :datetime then :datetime
            when :number, :integer then :number
            when :decimal, :float then :decimal
            when :hidden then :hidden
            when :email then :email
            when :url then :url
            when :password then :password
            when :color then :color
            when :range then :range
            when :time then :time
            else :text # Default fallback
            end
          end

          # Converts panel field options to form field options
          #
          # @param panel_options [Hash] options from panel field definition
          # @param field_type [Symbol] the field type for context-specific conversion
          # @return [Hash] form field options
          def convert_panel_options_to_form_options(panel_options, field_type)
            form_options = {}

            # Direct mappings - these options work the same in both systems
            direct_mappings = [
              :required, :label, :help, :placeholder, :default,
              :min, :max, :step, :pattern, :rows, :cols,
              :multiple, :accept, :autocomplete, :readonly,
              :disabled, :include_blank
            ]

            direct_mappings.each do |option|
              form_options[option] = panel_options[option] if panel_options.key?(option)
            end

            # Special handling for select field options
            if field_type == :select && panel_options[:options]
              form_options[:options] = normalize_select_options(panel_options[:options])
            end

            # Handle validation options
            if panel_options[:validation]
              form_options.merge!(panel_options[:validation])
            end

            form_options
          end

          # Normalizes select field options to ensure consistent format
          #
          # @param options [Array, Hash] the select options
          # @return [Array, Hash] normalized options
          def normalize_select_options(options)
            case options
            when Array
              # Convert array to hash if all elements are strings
              if options.all? { |opt| opt.is_a?(String) }
                options.each_with_object({}) { |opt, hash| hash[opt.humanize] = opt }
              else
                options
              end
            when Hash
              options
            else
              # Fallback for other types
              Array(options)
            end
          end
        end
      end
    end
  end
end