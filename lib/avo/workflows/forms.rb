# frozen_string_literal: true

require 'active_model'

module Avo
  module Workflows
    # Workflow forms system for collecting action-specific data
    #
    # Provides form builders and field definitions for workflow actions that require
    # user input beyond just triggering the action. Integrates with Avo's form system
    # to provide rich data collection interfaces.
    #
    # @example Basic usage
    #   class ApproveDocumentForm < Avo::Workflows::Forms::Base
    #     field :approval_comments, as: :textarea, required: true
    #     field :notify_stakeholders, as: :boolean, default: true
    #     field :priority_level, as: :select, options: ['low', 'medium', 'high']
    #   end
    #
    module Forms
      # Base class for workflow action forms
      class Base
        include ActiveModel::Model
        include ActiveModel::Attributes
        include ActiveModel::Validations

        attr_accessor :workflow_execution, :current_user, :action_name

        class_attribute :field_definitions, default: []
        class_attribute :form_title
        class_attribute :form_description

        def initialize(attributes = {})
          @workflow_execution = attributes.delete(:workflow_execution)
          @current_user = attributes.delete(:current_user) 
          @action_name = attributes.delete(:action_name)
          super(attributes)
        end

        # DSL for defining form fields
        def self.field(name, as:, **options)
          field_definitions << {
            name: name,
            type: as,
            options: options
          }

          # Define attribute and accessor
          attribute name, field_type_to_active_model_type(as), **attribute_options(options)
          
          # Add validation if required
          validates name, presence: true if options[:required]
        end

        # Set form metadata
        def self.title(text)
          self.form_title = text
        end

        def self.description(text)
          self.form_description = text
        end

        # Convert field type to ActiveModel type
        def self.field_type_to_active_model_type(field_type)
          case field_type
          when :text, :textarea, :select, :hidden then :string
          when :boolean then :boolean
          when :number, :integer then :integer
          when :decimal, :float then :float
          when :date then :date
          when :datetime then :datetime
          when :json then :string
          else :string
          end
        end

        # Extract ActiveModel attribute options
        def self.attribute_options(options)
          active_model_options = {}
          active_model_options[:default] = options[:default] if options.key?(:default)
          active_model_options
        end

        # Get form data as context hash
        def to_context
          field_definitions.each_with_object({}) do |field_def, context|
            field_name = field_def[:name]
            context[field_name] = send(field_name)
          end
        end

        # Check if form has any fields
        def self.has_fields?
          field_definitions.any?
        end

        # Get field definition by name
        def self.field_definition(name)
          field_definitions.find { |field| field[:name] == name }
        end

        # Render form using Avo components
        def render_avo_form
          return nil unless self.class.has_fields?

          {
            title: self.class.form_title || "#{action_name.to_s.humanize} Form",
            description: self.class.form_description,
            fields: self.class.field_definitions.map { |field_def| render_field(field_def) }
          }
        end

        private

        def render_field(field_def)
          base_field = {
            name: field_def[:name],
            type: field_def[:type],
            label: field_def[:options][:label] || field_def[:name].to_s.humanize,
            required: field_def[:options][:required] || false,
            help: field_def[:options][:help],
            value: send(field_def[:name])
          }

          # Add type-specific options
          case field_def[:type]
          when :select
            base_field[:options] = field_def[:options][:options] || []
          when :textarea
            base_field[:rows] = field_def[:options][:rows] || 4
          when :boolean
            base_field[:default] = field_def[:options][:default] || false
          end

          base_field
        end
      end

      # Registry for workflow action forms
      class Registry
        class_attribute :forms, default: {}

        # Register a form for a specific workflow action
        def self.register(workflow_class, action_name, form_class)
          key = "#{workflow_class.name}##{action_name}"
          forms[key] = form_class
        end

        # Get form class for workflow action
        def self.get(workflow_class, action_name)
          key = "#{workflow_class.name}##{action_name}"
          forms[key]
        end

        # Check if action has a form
        def self.has_form?(workflow_class, action_name)
          key = "#{workflow_class.name}##{action_name}"
          forms.key?(key)
        end

        # Get all registered forms
        def self.all_forms
          forms
        end
      end

      # DSL for registering forms in workflow classes
      module WorkflowFormMethods
        def self.included(base)
          base.extend(ClassMethods)
        end

        module ClassMethods
          # Register a form for an action
          def action_form(action_name, form_class)
            Avo::Workflows::Forms::Registry.register(self, action_name, form_class)
          end

          # Define inline form for an action
          def action_form_for(action_name, &block)
            form_class = Class.new(Avo::Workflows::Forms::Base)
            form_class.class_eval(&block)
            action_form(action_name, form_class)
          end

          # Get form class for action
          def form_for_action(action_name)
            Avo::Workflows::Forms::Registry.get(self, action_name)
          end

          # Check if action has form
          def action_has_form?(action_name)
            Avo::Workflows::Forms::Registry.has_form?(self, action_name)
          end
        end
      end

      # Common form fields for workflow actions
      module CommonFields
        def self.approval_fields
          [
            { name: :approval_comments, as: :textarea, required: false, 
              label: 'Comments', help: 'Optional comments about this approval' },
            { name: :notify_stakeholders, as: :boolean, default: true,
              label: 'Notify Stakeholders', help: 'Send notification emails to relevant parties' }
          ]
        end

        def self.assignment_fields
          [
            { name: :assigned_user_id, as: :select, required: true,
              label: 'Assign To', help: 'Select user to assign this task to' },
            { name: :due_date, as: :date, required: false,
              label: 'Due Date', help: 'Optional deadline for completion' },
            { name: :priority, as: :select, required: false, default: 'medium',
              options: ['low', 'medium', 'high', 'urgent'],
              label: 'Priority Level' }
          ]
        end

        def self.rejection_fields
          [
            { name: :rejection_reason, as: :textarea, required: true,
              label: 'Reason for Rejection', help: 'Explain why this is being rejected' },
            { name: :suggested_changes, as: :textarea, required: false,
              label: 'Suggested Changes', help: 'Recommend specific improvements' },
            { name: :allow_resubmission, as: :boolean, default: true,
              label: 'Allow Resubmission', help: 'Can this be resubmitted after changes?' }
          ]
        end
      end
    end
  end
end