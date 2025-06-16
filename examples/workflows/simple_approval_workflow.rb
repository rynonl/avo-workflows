# frozen_string_literal: true

# Simple Approval Workflow - Demonstrates the new integrated step-form DSL
#
# This example shows how the new DSL makes workflow definition incredibly simple and intuitive.
# Everything needed for a workflow step is contained within the step block:
# - Actions (workflow graph)
# - Panel (form fields)  
# - on_submit (business logic)
#
# Usage:
#   document = Post.create!(title: 'My Document', content: 'Content here', user: user)
#   execution = SimpleApprovalWorkflow.create_execution_for(document, assigned_to: author)
#   
#   # User submits form through Avo interface, which triggers on_submit handler
#   # The handler processes the form data and determines the next workflow step

class SimpleApprovalWorkflow < Avo::Workflows::Base
  
  step :draft do
    describe 'Document is being drafted and prepared for review'
    requirement 'Document must have title and content'
    
    # Define possible transitions
    action :submit_for_review, to: :review
    action :save_draft, to: :draft  # Self-transition for saving progress
    
    # Define the form panel users will see
    panel do
      field :title, as: :text, required: true, 
            label: 'Document Title',
            help: 'Enter a clear, descriptive title'
            
      field :content, as: :textarea, required: true,
            label: 'Document Content', 
            help: 'Main content of the document'
            
      field :category, as: :select, required: true,
            options: ['blog', 'news', 'announcement', 'policy'],
            label: 'Category'
            
      field :tags, as: :text,
            label: 'Tags',
            help: 'Comma-separated tags'
            
      field :urgent, as: :boolean, default: false,
            label: 'Mark as Urgent',
            help: 'Urgent documents get priority review'
            
      field :action_choice, as: :select, required: true,
            options: ['save_draft', 'submit_for_review'],
            label: 'What would you like to do?'
    end
    
    # Define what happens when the form is submitted
    on_submit do |fields, user|
      # Validate required fields
      if fields[:title].blank? || fields[:content].blank?
        raise 'Title and content are required'
      end
      
      # Update the document with form data
      workflowable.update!(
        title: fields[:title],
        content: fields[:content]
      )
      
      # Store additional data in workflow context
      update_context(
        last_edited_by: user.id,
        last_edited_at: Time.current,
        category: fields[:category],
        tags: fields[:tags]&.split(',')&.map(&:strip),
        urgent: fields[:urgent],
        word_count: fields[:content].split.length
      )
      
      # Determine next step based on user choice
      case fields[:action_choice]
      when 'submit_for_review'
        if fields[:urgent]
          # Urgent documents get high priority
          perform_action(:submit_for_review, user: user, additional_context: { priority: 'high' })
        else
          perform_action(:submit_for_review, user: user, additional_context: { priority: 'normal' })
        end
      when 'save_draft'
        # Stay in draft state but update context
        perform_action(:save_draft, user: user)
      else
        raise 'Invalid action choice'
      end
    end
  end
  
  step :review do
    describe 'Document is under review by editor or manager'
    requirement 'Document must be complete'
    requirement 'Reviewer must be assigned'
    
    # Define possible transitions  
    action :approve, to: :approved
    action :reject, to: :rejected
    action :request_changes, to: :draft
    
    # Define review form
    panel do
      field :reviewer_comments, as: :textarea, required: true,
            label: 'Review Comments',
            help: 'Provide detailed feedback on the document'
            
      field :quality_score, as: :number, required: true,
            min: 1, max: 10,
            label: 'Quality Score (1-10)',
            help: 'Rate the overall quality of the document'
            
      field :grammar_check, as: :boolean, default: true,
            label: 'Grammar and spelling are correct'
            
      field :factual_accuracy, as: :boolean, default: true,
            label: 'Information is factually accurate'
            
      field :review_decision, as: :select, required: true,
            options: ['approve', 'reject', 'request_changes'],
            label: 'Review Decision'
    end
    
    # Handle review form submission
    on_submit do |fields, user|
      # Store review data in context
      update_context(
        reviewed_by: user.id,
        reviewed_at: Time.current,
        reviewer_comments: fields[:reviewer_comments],
        quality_score: fields[:quality_score],
        grammar_check: fields[:grammar_check],
        factual_accuracy: fields[:factual_accuracy]
      )
      
      # Apply business rules and perform appropriate action
      case fields[:review_decision]
      when 'approve'
        # Only approve if quality is sufficient
        if fields[:quality_score] >= 7 && fields[:grammar_check] && fields[:factual_accuracy]
          perform_action(:approve, user: user)
        else
          raise 'Cannot approve: Quality score must be 7+, grammar and facts must be correct'
        end
      when 'reject'
        perform_action(:reject, user: user)
      when 'request_changes'
        perform_action(:request_changes, user: user)
      else
        raise 'Invalid review decision'
      end
    end
  end
  
  step :approved do
    describe 'Document approved and ready for publication'
    # Final state - no actions needed
    # In a real app, this might trigger publication workflows
  end
  
  step :rejected do
    describe 'Document rejected and needs major revision'
    
    action :start_over, to: :draft
    
    panel do
      field :rejection_reason, as: :textarea, required: true,
            label: 'Reason for Starting Over',
            help: 'Explain what needs to be changed'
            
      field :keep_draft_content, as: :boolean, default: true,
            label: 'Keep existing content as starting point'
    end
    
    on_submit do |fields, user|
      # Clear previous content if requested
      unless fields[:keep_draft_content]
        workflowable.update!(content: '')
      end
      
      # Record restart information
      update_context(
        restarted_by: user.id,
        restarted_at: Time.current,
        rejection_reason: fields[:rejection_reason],
        content_kept: fields[:keep_draft_content]
      )
      
      perform_action(:start_over, user: user)
    end
  end
end