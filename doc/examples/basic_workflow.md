# Basic Workflow Example

This example demonstrates creating and using a simple workflow.

## 1. Define the Workflow

```ruby
class SimpleApprovalWorkflow < Avo::Workflows::Base
  step :draft do
    action :submit_for_review, to: :under_review
  end
  
  step :under_review do
    action :approve, to: :approved
    action :reject, to: :draft
  end
  
  step :approved
end
```

## 2. Use the Workflow

```ruby
# Attach to a model
document = Document.create!(title: "Important Document")
workflow = document.start_workflow!(SimpleApprovalWorkflow, user: current_user)

# Perform actions
workflow.perform_action(:submit_for_review, user: current_user)
workflow.perform_action(:approve, user: manager)

# Check status
puts workflow.current_step  # => "approved"
```
