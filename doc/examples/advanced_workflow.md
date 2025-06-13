# Advanced Workflow Example

This example shows advanced workflow features including validations,
conditions, and custom logic.

## Complex Workflow Definition

```ruby
class AdvancedDocumentWorkflow < Avo::Workflows::Base
  step :draft do
    validate :content_present
    validate :author_assigned
    
    action :submit_for_review, to: :under_review do
      condition { |execution| execution.workflowable.content.present? }
      effect { |execution| execution.workflowable.update!(submitted_at: Time.current) }
    end
  end
  
  step :under_review do
    action :approve, to: :approved do
      condition { |execution| execution.context[:reviewer_role] == 'manager' }
      effect { |execution| NotificationService.send_approval(execution.workflowable) }
    end
    
    action :request_changes, to: :needs_revision do
      effect { |execution| 
        execution.update_context!(
          feedback: execution.context[:review_comments],
          revision_requested_at: Time.current
        )
      }
    end
  end
  
  step :needs_revision do
    action :resubmit, to: :under_review do
      condition { |execution| execution.workflowable.updated_at > execution.context[:revision_requested_at] }
    end
  end
  
  step :approved
  
  private
  
  def content_present
    errors.add(:base, "Content is required") if workflowable.content.blank?
  end
  
  def author_assigned
    errors.add(:base, "Author must be assigned") if workflowable.author.blank?
  end
end
```
