# Workflow Forms Guide

This guide covers the comprehensive workflow forms system that allows you to collect rich data for each workflow action through Avo admin interface forms.

## Overview

The Workflow Forms system bridges the gap between workflow actions and data collection by providing:

- **Form Definitions** - Define fields and validation for each workflow action
- **Avo Integration** - Automatic form rendering in Avo admin interface  
- **Data Validation** - Built-in validation with custom rules
- **Context Integration** - Form data automatically added to workflow context
- **Type Safety** - Strongly typed form fields with proper conversion

## Quick Start

### 1. Define a Form Class

```ruby
# app/avo/forms/approval_form.rb
class ApprovalForm < Avo::Workflows::Forms::Base
  title "Document Approval"
  description "Provide approval details and comments"

  field :approval_comments, as: :textarea, required: true,
        label: "Approval Comments",
        help: "Explain your approval decision"
        
  field :notify_stakeholders, as: :boolean, default: true,
        label: "Notify Stakeholders",
        help: "Send notification emails to relevant parties"
        
  field :priority_level, as: :select, required: true,
        options: ["low", "medium", "high", "urgent"],
        label: "Priority Level"

  # Custom validation
  validates :approval_comments, length: { minimum: 10 }
end
```

### 2. Register Form with Workflow Action

```ruby
# app/workflows/document_approval_workflow.rb
class DocumentApprovalWorkflow < Avo::Workflows::Base
  include Avo::Workflows::Forms::WorkflowFormMethods

  step :under_review do
    action :approve, to: :approved
    action :reject, to: :rejected
  end

  # Register the form with the action
  action_form :approve, ApprovalForm
end
```

### 3. Configure Avo Resource

```ruby
# app/avo/resources/document_resource.rb
class DocumentResource < Avo::BaseResource
  include Avo::Workflows::ResourceMethods

  # Workflow action field will automatically show forms
  field :workflow_actions, as: :workflow_actions,
        show_on: :show,
        confirm_dangerous: true

  # Or create specific action with form
  action_for_workflow :approve do |action|
    action.name = "Approve Document"
    action.icon = "heroicons/outline/check"
    action.confirm_button_label = "Approve"
  end
end
```

## Form Field Types

### Text Fields

```ruby
class MyForm < Avo::Workflows::Forms::Base
  # Single line text
  field :title, as: :text, required: true
  
  # Multi-line text
  field :description, as: :textarea, required: false,
        rows: 4,
        help: "Detailed description"
        
  # Hidden field
  field :reference_id, as: :hidden
end
```

### Selection Fields

```ruby
class MyForm < Avo::Workflows::Forms::Base
  # Dropdown selection
  field :priority, as: :select, required: true,
        options: ["low", "medium", "high"],
        label: "Priority Level"
        
  # Or with custom labels
  field :status, as: :select,
        options: {
          "Draft" => "draft",
          "In Review" => "review", 
          "Published" => "published"
        }
end
```

### Boolean Fields

```ruby
class MyForm < Avo::Workflows::Forms::Base
  field :send_notifications, as: :boolean, default: true,
        label: "Send Email Notifications"
        
  field :urgent_processing, as: :boolean, default: false,
        label: "Mark as Urgent"
end
```

### Date and Time Fields

```ruby
class MyForm < Avo::Workflows::Forms::Base
  field :due_date, as: :date, required: true,
        label: "Due Date"
        
  field :scheduled_at, as: :datetime,
        label: "Schedule Publication"
end
```

### Numeric Fields

```ruby
class MyForm < Avo::Workflows::Forms::Base
  field :quantity, as: :number, required: true,
        label: "Quantity"
        
  field :budget, as: :decimal,
        label: "Budget Amount"
end
```

## Advanced Form Features

### Custom Validation

```ruby
class EquipmentAssignmentForm < Avo::Workflows::Forms::Base
  field :laptop_model, as: :select, required: true,
        options: ["MacBook Pro", "MacBook Air", "ThinkPad"]
        
  field :laptop_serial, as: :text, required: true
  
  field :additional_monitor, as: :boolean
  field :monitor_size, as: :select,
        options: ["24 inch", "27 inch", "32 inch"]

  # Custom validation logic
  validates :laptop_serial, format: { 
    with: /\A[A-Z0-9]{10,15}\z/, 
    message: "must be 10-15 alphanumeric characters" 
  }
  
  validate :monitor_size_required_if_additional_monitor

  private

  def monitor_size_required_if_additional_monitor
    if additional_monitor && monitor_size.blank?
      errors.add(:monitor_size, "is required when additional monitor is selected")
    end
  end
end
```

### Dynamic Field Options

```ruby
class TrainingAssignmentForm < Avo::Workflows::Forms::Base
  field :department, as: :select, required: true,
        options: -> { Department.active.pluck(:name) }
        
  field :training_modules, as: :textarea,
        help: "List required training modules for this department"
        
  # Access workflow context in validation
  validate :appropriate_training_for_role

  private

  def appropriate_training_for_role
    employee = workflow_execution.workflowable
    if employee.role == 'manager' && !training_modules.include?('leadership')
      errors.add(:training_modules, "must include leadership training for managers")
    end
  end
end
```

### Conditional Fields

```ruby
class RejectionForm < Avo::Workflows::Forms::Base
  field :rejection_reason, as: :select, required: true,
        options: [
          "Incomplete Documentation",
          "Failed Background Check",
          "Skills Assessment Failed", 
          "Other"
        ]
        
  field :detailed_reason, as: :textarea, required: false,
        label: "Detailed Explanation"
        
  field :resubmission_allowed, as: :boolean, default: true,
        label: "Allow Resubmission"
        
  field :resubmission_timeframe, as: :select,
        options: ["Immediately", "30 days", "90 days", "1 year"],
        label: "Resubmission Timeframe"

  # Conditional validation
  validates :detailed_reason, presence: true, if: :other_rejection_reason?
  validates :resubmission_timeframe, presence: true, if: :resubmission_allowed?

  private

  def other_rejection_reason?
    rejection_reason == "Other"
  end
end
```

## Form Integration Patterns

### Employee Onboarding Example

Complete example showing form integration for complex workflow:

```ruby
# Document Collection Form
class DocumentCollectionForm < Avo::Workflows::Forms::Base
  title "Collect Required Documents"
  description "Track which documents have been collected and verified"

  field :id_verification, as: :boolean, required: true,
        label: "Government ID Verified"
        
  field :tax_forms_complete, as: :boolean, required: true,
        label: "Tax Forms (W-4, I-9) Complete"
        
  field :emergency_contacts, as: :boolean, required: true,
        label: "Emergency Contact Information"
        
  field :benefits_enrollment, as: :boolean,
        label: "Benefits Enrollment Complete"
        
  field :documentation_notes, as: :textarea,
        label: "Additional Notes",
        help: "Any special circumstances or missing items"

  validates :id_verification, :tax_forms_complete, :emergency_contacts,
            inclusion: { in: [true], message: "is required for onboarding" }
end

# Equipment Assignment Form  
class EquipmentAssignmentForm < Avo::Workflows::Forms::Base
  title "Assign IT Equipment"
  description "Specify equipment allocated to new employee"

  field :laptop_model, as: :select, required: true,
        options: ["MacBook Pro 14\"", "MacBook Pro 16\"", "ThinkPad X1"],
        label: "Laptop Assignment"
        
  field :laptop_serial, as: :text, required: true,
        label: "Serial Number"
        
  field :monitor_assignment, as: :select,
        options: ["None", "Dell 24\"", "Dell 27\"", "LG 32\" 4K"],
        label: "Monitor Assignment"
        
  field :phone_required, as: :boolean,
        label: "Company Phone Required"
        
  field :phone_model, as: :select,
        options: ["iPhone 15", "iPhone 15 Pro", "Samsung Galaxy S24"],
        label: "Phone Model"
        
  field :software_licenses, as: :textarea,
        label: "Software Licenses",
        help: "List required software (Adobe, Slack, etc.)"

  validates :laptop_model, :laptop_serial, presence: true
  validates :phone_model, presence: true, if: :phone_required?
end

# Register forms with workflow
class EmployeeOnboardingWorkflow < Avo::Workflows::Base
  action_form :collect_documents, DocumentCollectionForm
  action_form :assign_equipment, EquipmentAssignmentForm
end
```

### Document Approval Example

```ruby
class DocumentApprovalForm < Avo::Workflows::Forms::Base
  title "Document Approval Decision"
  
  field :approval_status, as: :select, required: true,
        options: ["Approved", "Approved with Changes", "Rejected"],
        label: "Approval Decision"
        
  field :approval_comments, as: :textarea, required: true,
        label: "Comments",
        help: "Provide detailed feedback on your decision"
        
  field :required_changes, as: :textarea,
        label: "Required Changes",
        help: "Specific changes needed (if applicable)"
        
  field :notify_author, as: :boolean, default: true,
        label: "Notify Document Author"
        
  field :notify_stakeholders, as: :boolean, default: false,
        label: "Notify All Stakeholders"
        
  field :escalate_to_director, as: :boolean, default: false,
        label: "Escalate to Director"

  validates :required_changes, presence: true, 
            if: -> { approval_status == "Approved with Changes" }
end
```

## Avo Resource Integration

### Basic Action Integration

```ruby
class DocumentResource < Avo::BaseResource
  include Avo::Workflows::ResourceMethods

  # Automatic form integration
  field :workflow_actions, as: :workflow_actions,
        show_on: :show

  # Custom action with form
  action_for_workflow :approve do |action|
    action.name = "Approve Document"
    action.icon = "heroicons/outline/check-circle"
    action.message = "Document approved successfully"
  end
end
```

### Advanced Resource Configuration

```ruby
class EmployeeResource < Avo::BaseResource
  include Avo::Workflows::ResourceMethods

  # Workflow status display
  field :workflow_status, as: :workflow_progress,
        show_percentage: true,
        color_coding: true

  # Multiple workflow actions with forms
  action_for_workflow :collect_documents do |action|
    action.name = "Collect Documents"
    action.icon = "heroicons/outline/document-text"
    action.visible = -> { resource.workflow_execution&.can_perform_action?(:collect_documents, current_user) }
  end

  action_for_workflow :assign_equipment do |action|
    action.name = "Assign Equipment" 
    action.icon = "heroicons/outline/computer-desktop"
    action.visible = -> { current_user.it_department? }
  end

  action_for_workflow :final_approval do |action|
    action.name = "Complete Onboarding"
    action.icon = "heroicons/outline/check-badge"
    action.confirm_button_label = "Complete Onboarding"
    action.dangerous = false
  end

  # Bulk action with form
  action :bulk_assign_training do
    self.name = "Assign Training (Bulk)"
    self.standalone = false

    field :training_program, as: :select, required: true,
          options: ["New Hire Orientation", "Safety Training", "Technical Training"]
          
    field :completion_deadline, as: :date, required: true
    
    def handle(**args)
      models = args[:models]
      training_data = {
        program: args[:fields][:training_program],
        deadline: args[:fields][:completion_deadline]
      }

      models.each do |employee|
        next unless employee.workflow_execution&.can_perform_action?(:assign_training, current_user)
        
        employee.workflow_execution.perform_action(
          :assign_training,
          user: current_user,
          context: training_data
        )
      end

      succeed "Training assigned to #{models.size} employees"
    end
  end
end
```

## Form Data Access

### In Workflow Actions

Form data is automatically added to the workflow context:

```ruby
class DocumentApprovalWorkflow < Avo::Workflows::Base
  step :under_review do
    action :approve, to: :approved do
      # Form data available in action conditions and effects
      effect do |execution|
        # Access form data from context
        approval_comments = execution.context[:approval_comments]
        notify_stakeholders = execution.context[:notify_stakeholders]
        
        # Send notifications if requested
        if notify_stakeholders
          NotificationService.send_approval_notification(
            document: execution.workflowable,
            comments: approval_comments
          )
        end
        
        # Update document with approval details
        execution.workflowable.update!(
          approved_at: Time.current,
          approval_comments: approval_comments,
          approved_by: execution.user
        )
      end
    end
  end
end
```

### In Workflow Context

```ruby
# Access rich form data in workflow execution
execution = document.workflow_execution

# Get all collected documents data
documents_data = execution.context.slice(
  :id_verification, 
  :tax_forms_complete, 
  :emergency_contacts,
  :documentation_notes
)

# Get equipment assignment details
equipment_data = execution.context.slice(
  :laptop_model,
  :laptop_serial, 
  :monitor_assignment,
  :software_licenses
)

# Generate reports from workflow data
OnboardingReport.generate(
  employee: execution.workflowable,
  documents: documents_data,
  equipment: equipment_data,
  timeline: execution.step_history
)
```

## Testing Forms

### RSpec Examples

```ruby
RSpec.describe DocumentCollectionForm do
  let(:workflow_execution) { create(:workflow_execution) }
  let(:user) { create(:user) }
  
  describe "validations" do
    it "requires essential documents" do
      form = described_class.new(
        workflow_execution: workflow_execution,
        current_user: user,
        id_verification: false
      )
      
      expect(form).not_to be_valid
      expect(form.errors[:id_verification]).to include("is required for onboarding")
    end
    
    it "accepts valid document collection data" do
      form = described_class.new(
        workflow_execution: workflow_execution,
        current_user: user,
        id_verification: true,
        tax_forms_complete: true,
        emergency_contacts: true,
        documentation_notes: "All documents verified"
      )
      
      expect(form).to be_valid
    end
  end
  
  describe "#to_context" do
    it "converts form data to context hash" do
      form = described_class.new(
        id_verification: true,
        tax_forms_complete: true,
        documentation_notes: "Complete"
      )
      
      context = form.to_context
      expect(context).to include(
        id_verification: true,
        tax_forms_complete: true,
        documentation_notes: "Complete"
      )
    end
  end
end
```

### Integration Tests

```ruby
RSpec.describe "Workflow Forms Integration" do
  let(:employee) { create(:employee) }
  let(:hr_user) { create(:user, :hr_role) }
  
  it "collects document data through form" do
    workflow = employee.start_onboarding!(assigned_to: hr_user)
    
    # Simulate form submission
    form_data = {
      id_verification: true,
      tax_forms_complete: true,
      emergency_contacts: true,
      documentation_notes: "All documents collected and verified"
    }
    
    # Perform action with form data
    workflow.perform_action(
      :collect_documents,
      user: hr_user,
      context: form_data
    )
    
    # Verify form data is stored in context
    expect(workflow.context_data).to include(form_data)
    expect(workflow.current_step).to eq("documentation_complete")
  end
end
```

## Best Practices

### 1. Form Organization

```ruby
# Organize forms by workflow or domain
# app/avo/forms/employee_onboarding/
#   ├── document_collection_form.rb
#   ├── equipment_assignment_form.rb
#   ├── training_assignment_form.rb
#   └── final_approval_form.rb

# Use consistent naming
class EmployeeOnboarding::DocumentCollectionForm < Avo::Workflows::Forms::Base
  # Form definition
end
```

### 2. Validation Strategy

```ruby
class MyForm < Avo::Workflows::Forms::Base
  # Use built-in validations where possible
  field :email, as: :text, required: true
  validates :email, format: { with: URI::MailTo::EMAIL_REGEXP }
  
  # Custom validations for business rules
  validate :deadline_is_in_future
  validate :manager_approval_for_high_priority
  
  private
  
  def deadline_is_in_future
    return unless due_date.present?
    
    if due_date <= Date.current
      errors.add(:due_date, "must be in the future")
    end
  end
end
```

### 3. Performance Considerations

```ruby
class MyForm < Avo::Workflows::Forms::Base
  # Cache expensive option lookups
  field :department, as: :select, 
        options: -> { Rails.cache.fetch("active_departments", expires_in: 1.hour) { Department.active.pluck(:name) } }
        
  # Limit large text fields
  field :notes, as: :textarea
  validates :notes, length: { maximum: 1000 }
end
```

The Workflow Forms system provides a complete solution for collecting rich, validated data through workflow actions, seamlessly integrated with the Avo admin interface while maintaining type safety and proper validation.