# frozen_string_literal: true

# Example BlogPost model demonstrating workflow integration
#
# This model shows how to integrate workflows with your domain models.
# The workflow tracks the approval process while the model handles the business logic.
#
# Key Integration Points:
# - Workflow execution is separate from model state
# - Model provides business logic and validation
# - Workflow manages process and transitions
# - Context flows between model and workflow

class BlogPost < ApplicationRecord
  # Associations
  belongs_to :author, class_name: 'User'
  belongs_to :editor, class_name: 'User', optional: true
  
  # The workflow execution tracks the approval process
  has_one :workflow_execution, 
          as: :workflowable, 
          class_name: 'Avo::Workflows::WorkflowExecution',
          dependent: :destroy

  # Validations
  validates :title, presence: true, length: { minimum: 5, maximum: 200 }
  validates :content, presence: true, length: { minimum: 50 }
  validates :author, presence: true
  
  # Optional fields
  validates :excerpt, length: { maximum: 500 }, allow_blank: true
  validates :tags, length: { maximum: 100 }, allow_blank: true
  validates :slug, uniqueness: true, allow_blank: true

  # Scopes for different workflow states
  scope :drafts, -> { joins(:workflow_execution).where(avo_workflow_executions: { current_step: 'draft' }) }
  scope :under_review, -> { joins(:workflow_execution).where(avo_workflow_executions: { current_step: 'under_review' }) }
  scope :published, -> { joins(:workflow_execution).where(avo_workflow_executions: { current_step: 'published' }) }

  # Convenience methods for workflow state
  
  # Checks if post is in draft state
  # @return [Boolean] true if post is in draft
  def draft?
    workflow_execution&.current_step == 'draft'
  end

  # Checks if post is under review
  # @return [Boolean] true if post is under review
  def under_review?
    workflow_execution&.current_step == 'under_review'
  end

  # Checks if post is published
  # @return [Boolean] true if post is published
  def published?
    workflow_execution&.current_step == 'published'
  end

  # Gets the current workflow step in human-readable form
  # @return [String] humanized step name
  def workflow_status
    workflow_execution&.current_step&.humanize || 'No workflow'
  end

  # Starts the blog post workflow
  #
  # @param assigned_to [User] the user to assign the workflow to (defaults to author)
  # @return [Avo::Workflows::WorkflowExecution] the created workflow execution
  def start_workflow!(assigned_to: nil)
    return workflow_execution if workflow_execution.present?

    assigned_user = assigned_to || author
    execution = BlogPostWorkflow.create_execution_for(
      self, 
      assigned_to: assigned_user,
      initial_context: initial_workflow_context
    )
    
    # Reload to get the association
    reload
    execution
  end

  # Submits post for review
  #
  # @param user [User] the user performing the action
  # @param notes [String] optional author notes for the editor
  # @return [Boolean] true if action was successful
  def submit_for_review!(user:, notes: nil)
    ensure_workflow_exists!
    
    context = { author_notes: notes }.compact
    workflow_execution.perform_action(:submit_for_review, user: user, additional_context: context)
  end

  # Approves the post for publication
  #
  # @param editor [User] the editor approving the post
  # @param notes [String] optional editor feedback
  # @return [Boolean] true if action was successful
  def approve_for_publication!(editor:, notes: nil)
    ensure_workflow_exists!
    
    # Assign editor if not already assigned
    update!(editor: editor) unless self.editor.present?
    
    context = { editor_notes: notes, approved_at: Time.current }.compact
    workflow_execution.perform_action(:approve, user: editor, additional_context: context)
  end

  # Requests changes from the author
  #
  # @param editor [User] the editor requesting changes
  # @param feedback [String] required feedback for the author
  # @return [Boolean] true if action was successful
  def request_changes!(editor:, feedback:)
    ensure_workflow_exists!
    
    raise ArgumentError, "Feedback is required when requesting changes" if feedback.blank?
    
    context = { 
      editor_feedback: feedback, 
      changes_requested_at: Time.current 
    }
    workflow_execution.perform_action(:request_changes, user: editor, additional_context: context)
  end

  # Gets available actions for current workflow state
  #
  # @return [Array<Symbol>] available action names
  def available_workflow_actions
    return [] unless workflow_execution

    workflow_execution.available_actions
  end

  # Gets workflow history for display
  #
  # @return [Array<Hash>] formatted history entries
  def workflow_history
    return [] unless workflow_execution

    workflow_execution.step_history || []
  end

  private

  # Ensures workflow exists, creating it if necessary
  def ensure_workflow_exists!
    start_workflow! unless workflow_execution.present?
  end

  # Builds initial context for workflow
  # @return [Hash] initial context data
  def initial_workflow_context
    {
      workflowable: self,
      post_title: title,
      author_id: author_id,
      created_at: Time.current,
      word_count: content&.split&.length || 0
    }
  end
end