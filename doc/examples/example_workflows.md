# Example Workflows Guide

This guide covers the comprehensive workflow examples included with Avo Workflows. Each example demonstrates different patterns and features you can use in your own workflows.

## Overview

The `examples/` directory contains production-ready workflows that showcase:

- **Complex multi-step processes** (Employee Onboarding - 588 lines)
- **Editorial workflows** (Blog Post Publishing)  
- **Approval processes** (Document Approval)
- **Issue tracking** (Issue Management)
- **Order processing** (E-commerce fulfillment)

## Employee Onboarding Workflow

**File:** `examples/workflows/employee_onboarding_workflow.rb`
**Model:** `examples/models/employee.rb`

The most comprehensive example showing enterprise-grade onboarding process.

### Features Demonstrated

- **Multi-phase workflow** (7 major steps)
- **Role-based permissions** (HR, IT, Manager roles)
- **Rich context management** (documents, equipment, training)
- **Conditional logic** (different paths for employee types)
- **Validation integration** (required documents, approvals)
- **Time tracking** (deadlines, SLA monitoring)

### Usage Example

```ruby
# Create employee
employee = Employee.create!(
  name: 'John Doe',
  email: 'john.doe@company.com',
  employee_type: 'full_time',
  department: 'Engineering',
  salary_level: 'senior',
  start_date: Date.current + 1.week,
  manager: manager_user,
  hr_representative: hr_user
)

# Start onboarding workflow
workflow = employee.start_onboarding!(assigned_to: hr_user)

# Initial setup phase
workflow.perform_action(:begin_documentation_review, user: hr_user)
workflow.perform_action(:collect_required_documents, user: hr_user)
workflow.perform_action(:complete_documentation, user: hr_user)

# IT setup phase  
workflow.perform_action(:begin_it_setup, user: it_user)
workflow.perform_action(:assign_equipment, user: it_user, context: {
  equipment: ['laptop', 'monitor', 'keyboard']
})
workflow.perform_action(:complete_it_setup, user: it_user)

# Training phase
workflow.perform_action(:schedule_training, user: hr_user, context: {
  training_modules: ['company_overview', 'security_training', 'role_specific']
})
workflow.perform_action(:complete_training, user: employee)

# Final approval
workflow.perform_action(:manager_approval, user: manager_user)
workflow.perform_action(:complete_onboarding, user: hr_user)

# Check final status
puts workflow.current_step
# => "onboarding_completed"
```

### Key Patterns

**Context Management:**
```ruby
# Rich context tracking throughout workflow
workflow.context_data
# => {
#   documents_collected: ['id_copy', 'tax_forms', 'emergency_contact'],
#   equipment_assigned: ['laptop_001', 'monitor_dell_27'],
#   training_completed: ['security', 'company_overview'],
#   manager_approval_date: "2025-06-13",
#   start_date: "2025-06-20"
# }
```

**Role-Based Actions:**
```ruby
# Different actions available to different roles
workflow.available_actions_for_user(hr_user)
# => [:collect_documents, :schedule_training, :complete_onboarding]

workflow.available_actions_for_user(it_user)  
# => [:assign_equipment, :setup_accounts]

workflow.available_actions_for_user(manager_user)
# => [:manager_approval]
```

## Blog Post Publishing Workflow

**File:** `examples/workflows/blog_post_workflow.rb`
**Model:** `examples/models/blog_post.rb`

Editorial workflow demonstrating content management patterns.

### Features Demonstrated

- **Content lifecycle management**
- **Multi-level review process**
- **Publishing controls**
- **SEO optimization steps**
- **Social media integration**

### Usage Example

```ruby
# Create blog post
blog_post = BlogPost.create!(
  title: 'Advanced Rails Patterns',
  content: 'Lorem ipsum...',
  author: author_user,
  category: 'technical'
)

# Start publishing workflow
workflow = blog_post.start_workflow!(BlogPostWorkflow, user: author_user)

# Author workflow
workflow.perform_action(:submit_for_review, user: author_user)

# Editor workflow
workflow.perform_action(:approve_content, user: editor_user)
workflow.perform_action(:optimize_seo, user: seo_specialist, context: {
  meta_description: 'Learn advanced Rails patterns...',
  keywords: ['rails', 'patterns', 'ruby']
})

# Publishing
workflow.perform_action(:schedule_publication, user: editor_user, context: {
  publish_at: 1.day.from_now,
  social_media_posts: true
})

workflow.perform_action(:publish, user: editor_user)
```

### Key Features

**Content Validation:**
```ruby
# Automatic content checks
step :draft do
  validate :content_quality
  validate :seo_requirements
  
  action :submit_for_review, to: :under_review do
    condition { |execution| execution.workflowable.content.length > 500 }
  end
end

private

def content_quality
  errors.add(:base, "Content too short") if workflowable.content.length < 300
  errors.add(:base, "Missing images") if workflowable.images.empty?
end
```

## Document Approval Workflow

**File:** `examples/workflows/document_approval_workflow.rb`

Simple but powerful approval process showing conditional logic.

### Features Demonstrated

- **Multi-level approvals**
- **Role-based permissions**  
- **Rejection handling**
- **Approval tracking**

### Usage Example

```ruby
document = Document.create!(title: "Policy Update", content: "...")
workflow = document.start_approval!(assigned_to: manager)

# Submit for review
workflow.perform_action(:submit_for_review, user: author)

# Manager review
if urgent_document?
  workflow.perform_action(:emergency_approve, user: director)
else
  workflow.perform_action(:approve, user: manager)
end
```

## Issue Tracking Workflow

**File:** `examples/workflows/issue_tracking_workflow.rb`

Bug/feature tracking system integration.

### Features Demonstrated

- **Priority-based routing**
- **Assignment automation**
- **Resolution tracking**
- **Customer communication**

### Usage Example

```ruby
issue = Issue.create!(
  title: "Login button not working",
  description: "Users can't click the login button",
  priority: 'high',
  reporter: customer_user
)

workflow = issue.start_workflow!(IssueTrackingWorkflow, user: support_user)

# Triage
workflow.perform_action(:assign_to_team, user: support_manager, context: {
  assigned_team: 'frontend',
  priority: 'high'
})

# Development
workflow.perform_action(:start_investigation, user: developer)
workflow.perform_action(:fix_issue, user: developer, context: {
  solution: 'Fixed CSS z-index conflict',
  commit_sha: 'abc123'
})

# Testing & Resolution
workflow.perform_action(:verify_fix, user: qa_user)
workflow.perform_action(:notify_customer, user: support_user)
workflow.perform_action(:close_issue, user: support_user)
```

## Order Fulfillment Workflow

**File:** `examples/workflows/order_fulfillment_workflow.rb`

E-commerce order processing workflow.

### Features Demonstrated

- **Payment processing integration**
- **Inventory management**
- **Shipping coordination**
- **Customer notifications**

### Usage Example

```ruby
order = Order.create!(
  customer: customer,
  items: [{ product_id: 1, quantity: 2 }],
  total: 29.99
)

workflow = order.start_fulfillment!

# Payment processing
workflow.perform_action(:process_payment, user: system_user)
workflow.perform_action(:reserve_inventory, user: warehouse_user)

# Fulfillment
workflow.perform_action(:pick_items, user: picker)
workflow.perform_action(:pack_order, user: packer)
workflow.perform_action(:ship_order, user: shipping_clerk, context: {
  tracking_number: 'TRK123456',
  carrier: 'FedEx'
})

# Delivery
workflow.perform_action(:confirm_delivery, user: system_user)
```

## Common Patterns Across Examples

### 1. Context Management

All examples demonstrate rich context usage:

```ruby
# Adding context during actions
workflow.perform_action(:action_name, user: user, context: {
  additional_data: 'value',
  timestamp: Time.current
})

# Accessing context in conditions
action :conditional_action do
  condition { |execution| execution.context[:priority] == 'high' }
end
```

### 2. Role-Based Permissions

```ruby
# Different users can perform different actions
step :review do
  action :approve, to: :approved do
    condition { |execution| execution.user_can_approve?(execution.current_user) }
  end
  
  action :reject, to: :rejected do
    condition { |execution| execution.user_can_review?(execution.current_user) }
  end
end
```

### 3. Validation Integration

```ruby
step :draft do
  validate :required_fields_present
  validate :business_rules_met
  
  # Actions only available if validations pass
  action :submit, to: :submitted
end

private

def required_fields_present
  errors.add(:base, "Title required") if workflowable.title.blank?
end
```

### 4. Error Handling

```ruby
begin
  workflow.perform_action(:risky_action, user: user)
rescue Avo::Workflows::Errors::ValidationError => e
  # Handle validation failures
  render json: { errors: e.validation_errors }
rescue Avo::Workflows::Errors::ActionNotAvailableError => e
  # Handle unavailable actions
  render json: { error: "Action not available: #{e.message}" }
end
```

## Testing Examples

Each workflow comes with comprehensive tests. See the `spec/examples/` directory for testing patterns:

```ruby
RSpec.describe EmployeeOnboardingWorkflow do
  it 'completes full onboarding process' do
    employee = create(:employee)
    workflow = employee.start_onboarding!(assigned_to: hr_user)
    
    # Test each step
    expect(workflow.available_actions).to include(:begin_documentation_review)
    workflow.perform_action(:begin_documentation_review, user: hr_user)
    
    # Verify state transitions
    expect(workflow.current_step).to eq('documentation_review')
    
    # Test complete workflow
    complete_full_onboarding(workflow)
    expect(workflow.current_step).to eq('onboarding_completed')
  end
end
```

## Integration with Avo

All example workflows integrate seamlessly with Avo admin interface:

```ruby
# app/avo/resources/employee_resource.rb
class EmployeeResource < Avo::BaseResource
  include Avo::Workflows::ResourceMethods
  
  field :name, as: :text
  field :workflow_status, as: :workflow_progress
  field :workflow_actions, as: :workflow_actions
  
  panel :onboarding_workflow, as: :workflow_step_panel
  panel :workflow_history, as: :workflow_history_panel
  
  action :start_onboarding, as: :workflow_action
end
```

## Next Steps

1. **Copy and modify** any example workflow for your needs
2. **Study the patterns** used in complex workflows like Employee Onboarding
3. **Run the examples** in your development environment
4. **Adapt the Avo integration** patterns for your admin interface

For more details on any specific workflow, see the source files in the `examples/workflows/` directory.