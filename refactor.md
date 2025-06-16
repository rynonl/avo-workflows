# Workflow System Refactor: Integrated Step-Form Architecture

## Current Architecture Analysis

### Current System Overview

The existing avo-workflows system has a **separation of concerns** approach where workflows, forms, and Avo integration are distinct components:

**Workflow Definition** (`lib/avo/workflows/base.rb`):
```ruby
class BlogPostWorkflow < Avo::Workflows::Base
  step :draft do
    action :submit_for_review, to: :under_review, condition: ->(ctx) { ... }
  end
end
```

**Form Definition** (`lib/avo/workflows/forms.rb`):
```ruby
class ApprovalForm < Avo::Workflows::Forms::Base
  field :comments, as: :textarea, required: true
end
```

**Form Registration** (manual):
```ruby
BlogPostWorkflow.action_form :approve, ApprovalForm
```

**Avo Integration** (separate configuration):
```ruby
class PostResource < Avo::BaseResource
  field :workflow_actions, as: :workflow_actions
end
```

### Current System Components Analysis

#### 1. Workflow Base Class (`lib/avo/workflows/base.rb`)
- **Purpose**: Defines workflow steps and actions
- **Key Methods**: `step`, `action`, `create_execution_for`
- **Architecture**: Class-level DSL with step definitions stored in `@@workflow_steps`
- **Action Storage**: Actions stored as hash with `:to`, `:condition`, `:description`

#### 2. Step Definition (`lib/avo/workflows/base.rb:234-300`)
```ruby
class StepDefinition
  attr_reader :name, :actions, :conditions, :description
  
  def action(name, to:, **options)
    @actions[name] = { to: to, **options }
  end
end
```

#### 3. Forms System (`lib/avo/workflows/forms.rb`)
- **Purpose**: Rich data collection with ActiveModel integration
- **Key Features**: Field definitions, validation, Avo field mapping
- **Architecture**: Separate form classes with manual registration
- **Field Types**: text, textarea, boolean, select, date, number, hidden

#### 4. Workflow Execution (`lib/avo/workflows/workflow_execution.rb`)
- **Purpose**: Runtime workflow state management
- **Key Methods**: `perform_action`, `available_actions`, context management
- **Database**: Stores current_step, context_data, workflow_class

#### 5. Avo Integration
- **WorkflowActionsField**: Renders available actions as buttons/forms
- **WorkflowActionWithForm**: Handles form submission and validation
- **ResourceMethods**: Convenience methods for Avo resources

### Current System Strengths
1. **Separation of Concerns**: Clean boundaries between workflow logic and forms
2. **Flexibility**: Manual form registration allows complex customizations
3. **Type Safety**: Rich field definitions with validation
4. **Avo Integration**: Native admin interface support
5. **Context Management**: Sophisticated context data handling

### Current System Limitations
1. **Manual Configuration**: Every action requires separate form creation/registration
2. **Scattered Definition**: Workflow logic spread across multiple files/classes
3. **Complex Setup**: Significant boilerplate for simple use cases
4. **Discoverability**: Hard to see all workflow requirements in one place
5. **Maintenance**: Changes require updates in multiple locations

## Proposed New Architecture

### Vision: Integrated Step-Form Architecture

The new architecture consolidates **all step information** into a single `step` block:

```ruby
class SimpleApprovalWorkflow < Avo::Workflows::Base
  step :draft do
    # Graph definition - possible transitions
    action :approve, to: :approved
    action :reject, to: :rejected

    # Form definition - what user sees/inputs
    panel do
      field :comments, as: :textarea, required: true
      field :priority, as: :select, options: ['low', 'medium', 'high']
      field :notify_stakeholders, as: :boolean, default: true
    end

    # Logic definition - what happens on form submit
    on_submit do |fields, user|
      # Custom business logic
      Document.find(context[:document_id]).update!(
        comments: fields[:comments],
        priority: fields[:priority]
      )

      # Determine next step based on form data
      if fields[:action_choice] == 'approve'
        perform_action(:approve, user: user)
      else
        perform_action(:reject, user: user) 
      end
    end
  end
end
```

### Key Benefits of New Architecture

1. **Single Source of Truth**: All step information in one place
2. **Automatic Form Generation**: No manual form classes needed
3. **Intuitive API**: Clear relationship between form and actions
4. **Reduced Boilerplate**: Minimal configuration for common cases
5. **Discoverability**: Easy to understand workflow requirements
6. **Maintainability**: Changes localized to single step block

## Detailed Refactor Plan

### Phase 1: Extend StepDefinition Class

**File**: `lib/avo/workflows/base.rb`

**Changes Needed**:

1. **Add Panel Support to StepDefinition**:
```ruby
class StepDefinition
  attr_reader :name, :actions, :conditions, :description, :panel_fields, :on_submit_handler

  def initialize(name)
    @name = name
    @actions = {}
    @conditions = []
    @panel_fields = []
    @on_submit_handler = nil
  end

  # New panel method for defining form fields
  def panel(&block)
    panel_builder = PanelBuilder.new
    panel_builder.instance_eval(&block)
    @panel_fields = panel_builder.fields
  end

  # New on_submit method for handling form submission
  def on_submit(&block)
    @on_submit_handler = block
  end
end
```

2. **Create PanelBuilder Class**:
```ruby
class PanelBuilder
  attr_reader :fields

  def initialize
    @fields = []
  end

  def field(name, as:, **options)
    @fields << {
      name: name,
      type: as,
      options: options
    }
  end
end
```

### Phase 2: Automatic Form Generation

**File**: `lib/avo/workflows/forms/auto_generated_form.rb` (new)

**Purpose**: Create dynamic form classes from step panel definitions

```ruby
module Avo::Workflows::Forms
  class AutoGeneratedForm < Base
    class << self
      def for_step(workflow_class, step_name)
        step_def = workflow_class.find_step(step_name)
        return nil unless step_def&.panel_fields&.any?

        # Create dynamic form class
        form_class = Class.new(Base) do
          # Set title from step
          title step_name.to_s.humanize
          
          # Add fields from panel definition
          step_def.panel_fields.each do |field_def|
            field field_def[:name], 
                  as: field_def[:type], 
                  **field_def[:options]
          end

          # Store reference to workflow step
          define_singleton_method :workflow_step do
            step_def
          end
        end

        form_class
      end
    end
  end
end
```

### Phase 3: Enhanced Workflow Execution

**File**: `lib/avo/workflows/workflow_execution.rb`

**Changes Needed**:

1. **Add Panel Form Support**:
```ruby
class WorkflowExecution
  # Get form class for current step
  def current_step_form_class
    step_def = workflow.class.find_step(current_step)
    return nil unless step_def&.panel_fields&.any?

    @current_step_form_class ||= Avo::Workflows::Forms::AutoGeneratedForm.for_step(
      workflow.class, 
      current_step.to_sym
    )
  end

  # Check if current step has a form
  def current_step_has_form?
    current_step_form_class.present?
  end

  # Handle form submission with on_submit callback
  def submit_step_form(form_data, user:)
    step_def = workflow.class.find_step(current_step)
    return false unless step_def&.on_submit_handler

    # Validate form data
    if current_step_form_class
      form_instance = current_step_form_class.new(form_data)
      unless form_instance.valid?
        return { success: false, errors: form_instance.errors }
      end
    end

    # Execute on_submit handler in workflow context
    workflow_instance = workflow.class.new(self)
    workflow_instance.instance_exec(form_data, user, &step_def.on_submit_handler)

    { success: true }
  end
end
```

### Phase 4: Update Avo Integration

**File**: `lib/avo/workflows/avo/fields/workflow_step_form_field.rb` (new)

**Purpose**: Single field that automatically renders current step form

```ruby
class WorkflowStepFormField < Avo::Fields::BaseField
  def initialize(id, **args, &block)
    super(id, **args, &block)

    @name ||= "Current Step Form"
    @id = id
  end

  def value
    # Get current step form from workflow execution
    return nil unless resource.workflow_execution
    
    step_form_class = resource.workflow_execution.current_step_form_class
    return nil unless step_form_class

    step_form_class
  end

  def fill_field(model, key, value, params)
    # Handle form submission through workflow execution
    return unless model.workflow_execution

    form_data = extract_form_data(params)
    result = model.workflow_execution.submit_step_form(
      form_data, 
      user: params[:current_user]
    )

    unless result[:success]
      # Handle validation errors
      add_errors_to_model(model, result[:errors])
    end
  end

  private

  def extract_form_data(params)
    # Extract form field data from params
    params.select { |k, v| k.to_s.starts_with?('step_form_') }
          .transform_keys { |k| k.to_s.gsub('step_form_', '') }
  end
end
```

**File**: `lib/avo/workflows/avo/actions/step_form_action.rb` (new)

**Purpose**: Single action that handles any step form submission

```ruby
class StepFormAction < Avo::BaseAction
  self.name = "Submit Step Form"
  self.standalone = false

  def handle(**args)
    models = Array(args[:models] || args[:model])
    form_data = args[:fields] || {}
    user = args[:current_user]

    models.each do |model|
      next unless model.workflow_execution
      
      result = model.workflow_execution.submit_step_form(form_data, user: user)
      
      unless result[:success]
        return error("Form submission failed: #{result[:errors]}")
      end
    end

    succeed("Step completed successfully")
  end

  def fields
    # Dynamically generate fields based on current step form
    return [] unless resource&.workflow_execution

    form_class = resource.workflow_execution.current_step_form_class
    return [] unless form_class

    form_class.field_definitions.map do |field_def|
      create_avo_field(field_def)
    end
  end

  private

  def create_avo_field(field_def)
    case field_def[:type]
    when :text
      field field_def[:name], as: :text, **field_def[:options]
    when :textarea  
      field field_def[:name], as: :textarea, **field_def[:options]
    when :boolean
      field field_def[:name], as: :boolean_group, **field_def[:options]
    when :select
      options = field_def[:options][:options] || []
      field field_def[:name], as: :select, options: options, **field_def[:options].except(:options)
    else
      field field_def[:name], as: :text, **field_def[:options]
    end
  end
end
```

### Phase 5: Enhanced Base Workflow Class

**File**: `lib/avo/workflows/base.rb`

**Changes Needed**:

1. **Add Perform Action Helper**:
```ruby
class Base
  # Instance method for use within on_submit blocks
  def perform_action(action_name, user:, additional_context: {})
    return false unless @execution

    @execution.perform_action(
      action_name, 
      user: user, 
      additional_context: additional_context
    )
  end

  # Access to current execution context
  def context
    @execution&.context_data || {}
  end

  # Update context data
  def update_context(new_data)
    @execution&.update_context!(new_data) if @execution
  end
end
```

### Phase 6: Backward Compatibility Layer

**File**: `lib/avo/workflows/forms/compatibility.rb` (new)

**Purpose**: Ensure existing manual form registration still works

```ruby
module Avo::Workflows::Forms
  module Compatibility
    extend ActiveSupport::Concern

    class_methods do
      # Legacy action_form method for backward compatibility
      def action_form(action_name, form_class)
        @legacy_action_forms ||= {}
        @legacy_action_forms[action_name] = form_class
      end

      def form_for_action(action_name)
        # Check legacy forms first
        return @legacy_action_forms[action_name] if @legacy_action_forms&.[](action_name)

        # Check auto-generated forms
        step_name = step_with_action(action_name)
        return nil unless step_name

        Avo::Workflows::Forms::AutoGeneratedForm.for_step(self, step_name)
      end

      private

      def step_with_action(action_name)
        workflow_steps&.find do |step_name, step_def|
          step_def.actions.key?(action_name.to_sym)
        end&.first
      end
    end
  end
end
```

### Phase 7: Resource Integration Helper

**File**: `lib/avo/workflows/avo/resource_methods.rb`

**Changes Needed**:

1. **Update Resource Methods**:
```ruby
module Avo::Workflows::ResourceMethods
  # Automatic step form field
  def workflow_step_form(**options)
    field :workflow_step_form, 
          as: :workflow_step_form,
          show_on: :show,
          **options
  end

  # Automatic step form action
  def workflow_step_action(**options)
    action :workflow_step_action,
           Avo::Workflows::Avo::Actions::StepFormAction,
           **options
  end

  # Convenience method to add both field and action
  def workflow_step_panel(**options)
    workflow_step_form(**options)
    workflow_step_action(**options)
  end
end
```

## Migration Strategy

### Phase 1: Core Infrastructure (Week 1)
1. Extend StepDefinition with panel and on_submit support
2. Create PanelBuilder for field definitions
3. Update Base class with instance methods
4. Add tests for new DSL methods

### Phase 2: Form Generation (Week 2)  
1. Create AutoGeneratedForm class
2. Implement dynamic form class generation
3. Add form field type mapping
4. Test form generation from step definitions

### Phase 3: Execution Integration (Week 3)
1. Update WorkflowExecution with form support
2. Implement submit_step_form method
3. Add form validation and error handling
4. Test execution flow with forms

### Phase 4: Avo Integration (Week 4)
1. Create new Avo field and action classes
2. Implement dynamic field generation
3. Update ResourceMethods with new helpers
4. Test full Avo integration

### Phase 5: Backward Compatibility (Week 5)
1. Implement compatibility layer
2. Ensure existing workflows continue working
3. Add migration guides for existing code
4. Update documentation and examples

### Phase 6: Testing & Documentation (Week 6)
1. Comprehensive testing of new architecture
2. Update all documentation
3. Create migration examples
4. Performance testing and optimization

## Example: Before vs After

### Before (Current System)
```ruby
# Workflow definition
class ApprovalWorkflow < Avo::Workflows::Base
  step :draft do
    action :submit, to: :review
  end
end

# Separate form class
class SubmitForm < Avo::Workflows::Forms::Base
  field :comments, as: :textarea, required: true
  field :priority, as: :select, options: ['low', 'high']
end

# Manual registration
ApprovalWorkflow.action_form :submit, SubmitForm

# Avo resource configuration
class DocumentResource < Avo::BaseResource
  include Avo::Workflows::ResourceMethods
  field :workflow_actions, as: :workflow_actions
end
```

### After (New System)
```ruby
# Everything in one place
class ApprovalWorkflow < Avo::Workflows::Base
  step :draft do
    action :submit, to: :review

    panel do
      field :comments, as: :textarea, required: true
      field :priority, as: :select, options: ['low', 'high']
    end

    on_submit do |fields, user|
      update_context(
        review_comments: fields[:comments],
        priority: fields[:priority]
      )
      perform_action(:submit, user: user)
    end
  end
end

# Simplified Avo resource
class DocumentResource < Avo::BaseResource
  include Avo::Workflows::ResourceMethods
  workflow_step_panel  # Single method adds everything needed
end
```

## Risk Assessment

### Low Risk
- Backward compatibility preservation
- Incremental migration path
- Existing test coverage

### Medium Risk  
- Avo integration complexity
- Dynamic form generation edge cases
- Performance impact of dynamic classes

### High Risk
- Major architectural changes
- Complex form validation scenarios
- Breaking changes in workflow execution

## Success Metrics

1. **Developer Experience**: Reduced lines of code for simple workflows by 60%
2. **Discoverability**: All workflow information visible in single file
3. **Maintainability**: Single location for workflow changes
4. **Performance**: No significant performance degradation
5. **Compatibility**: 100% backward compatibility with existing workflows

This refactor transforms avo-workflows from a **component-based** architecture to an **integrated step-based** architecture, making it much more intuitive and maintainable while preserving all existing functionality.