# Avo Workflows Examples

This directory contains example workflow implementations demonstrating different use cases and patterns for the Avo Workflows gem.

## Example Workflows

### 1. Document Approval Workflow (`document_approval_workflow.rb`)

A comprehensive document review and approval process with the following features:

- **Use Case**: Content management, legal document review, policy approval
- **Key Features**:
  - Multi-stage approval process
  - Escalation to senior reviewers
  - Revision cycles
  - Publishing and scheduling
  - Archive functionality

**Flow**: Draft → Review → Approval → Publishing → Archive

### 2. Order Fulfillment Workflow (`order_fulfillment_workflow.rb`)

Complete e-commerce order lifecycle management:

- **Use Case**: E-commerce, retail operations, inventory management
- **Key Features**:
  - Payment processing
  - Inventory management
  - Shipping and delivery tracking
  - Returns and exchanges
  - Multiple final states

**Flow**: Payment → Processing → Shipping → Delivery → Completion

### 3. Employee Onboarding Workflow (`employee_onboarding_workflow.rb`)

HR onboarding process with multiple stakeholders:

- **Use Case**: Human resources, employee management
- **Key Features**:
  - Offer management
  - Background checks
  - Training phases
  - Probation period tracking
  - Performance reviews

**Flow**: Offer → Background Check → Pre-boarding → Training → Full Employment

### 4. Issue Tracking Workflow (`issue_tracking_workflow.rb`)

Software development issue and bug tracking:

- **Use Case**: Software development, project management, customer support
- **Key Features**:
  - Triage process
  - Priority management
  - Development lifecycle
  - Quality assurance
  - Release management

**Flow**: New → Triage → Development → Testing → Resolution

## Usage Examples

### Setting up a Workflow

```ruby
# In your Rails application, create the workflow execution
execution = DocumentApprovalWorkflow.create_execution_for(
  document,
  assigned_to: current_user,
  initial_context: { 
    author_id: document.author_id,
    department: 'legal'
  }
)

# Check available actions
execution.available_actions
# => [:submit_for_review, :save_draft, :archive]

# Perform an action
execution.perform_action(:submit_for_review, user: current_user)
```

### Integration with Avo Resources

```ruby
# In your Avo resource file
class DocumentResource < Avo::BaseResource
  include Avo::Workflows::ResourceMethods
  
  workflow DocumentApprovalWorkflow
  
  def fields
    field :title, as: :text
    field :content, as: :textarea
    field :workflow_status, as: :select, options: -> { 
      current_record.workflow_execution&.current_step 
    }
  end
end
```

### Adding Workflow Conditions

```ruby
class DocumentApprovalWorkflow < Avo::Workflows::Base
  step :escalated_review do
    # Only managers can access this step
    condition { context[:user]&.role == 'manager' }
    
    action :senior_approve, to: :approved
    action :senior_reject, to: :rejected
  end
end
```

### Workflow Callbacks

```ruby
class DocumentApprovalWorkflow < Avo::Workflows::Base
  # Send notification when document is approved
  before_transition to: :approved do |execution|
    DocumentMailer.approval_notification(
      execution.workflowable,
      execution.assigned_to
    ).deliver_later
  end
  
  # Update timestamp when published
  before_transition to: :published do |execution|
    execution.workflowable.update(published_at: Time.current)
  end
end
```

## Best Practices

### 1. Keep Steps Atomic

Each step should represent a single, well-defined state:

```ruby
# Good
step :pending_review
step :approved
step :published

# Avoid
step :review_and_approve_and_publish
```

### 2. Use Descriptive Action Names

Action names should clearly indicate what they do:

```ruby
# Good
action :submit_for_review, to: :pending_review
action :approve_with_changes, to: :approved

# Avoid
action :next, to: :pending_review
action :ok, to: :approved
```

### 3. Handle Error Cases

Include steps for handling failures and edge cases:

```ruby
step :processing do
  action :complete, to: :completed
  action :error_occurred, to: :error_state
  action :timeout, to: :timed_out
end
```

### 4. Use Context Data Effectively

Store relevant information in the context:

```ruby
execution.perform_action(
  :approve, 
  user: current_user,
  additional_context: {
    approval_notes: "Looks good!",
    approved_at: Time.current
  }
)
```

### 5. Validate Workflow Definitions

Use the built-in validators:

```ruby
# Check for workflow definition issues
errors = Avo::Workflows::Validators.validate_workflow_definition(DocumentApprovalWorkflow)
puts errors if errors.any?
```

## Testing Workflows

Example RSpec test:

```ruby
RSpec.describe DocumentApprovalWorkflow do
  let(:document) { create(:document) }
  let(:execution) { described_class.create_execution_for(document) }
  
  it 'allows submission from draft' do
    expect(execution.can_transition_to?(:pending_review)).to be true
  end
  
  it 'transitions correctly on submit' do
    execution.perform_action(:submit_for_review)
    expect(execution.current_step).to eq('pending_review')
  end
end
```

## Contributing

When creating new example workflows:

1. Include comprehensive documentation
2. Demonstrate different workflow patterns
3. Add realistic business use cases
4. Include error handling examples
5. Show integration with Avo resources