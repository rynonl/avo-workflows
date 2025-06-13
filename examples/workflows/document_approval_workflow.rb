# frozen_string_literal: true

# Example: Document Approval Workflow
# A comprehensive workflow for document review and approval process
class DocumentApprovalWorkflow < Avo::Workflows::Base
  step :draft do
    action :submit_for_review, to: :pending_review
    action :save_draft, to: :draft
    action :archive, to: :archived
  end

  step :pending_review do
    action :approve, to: :approved
    action :reject, to: :rejected
    action :request_changes, to: :needs_revision
    action :escalate, to: :escalated_review
  end

  step :needs_revision do
    action :revise, to: :draft
    action :abandon, to: :archived
  end

  step :escalated_review do
    action :senior_approve, to: :approved
    action :senior_reject, to: :rejected
    action :return_to_review, to: :pending_review
  end

  step :approved do
    action :publish, to: :published
    action :schedule_publish, to: :scheduled
  end

  step :rejected do
    action :resubmit, to: :draft
    action :appeal, to: :escalated_review
    action :archive, to: :archived
  end

  step :published do
    action :unpublish, to: :approved
    action :archive, to: :archived
  end

  step :scheduled do
    action :publish_now, to: :published
    action :cancel_schedule, to: :approved
  end

  step :archived do
    action :restore, to: :draft
  end

  # Example of using step conditions
  # step :escalated_review do
  #   condition { context[:user]&.role == 'manager' }
  # end

  # Example of workflow callbacks
  # before_transition to: :approved do |execution|
  #   # Send notification to author
  #   DocumentMailer.approval_notification(execution.workflowable).deliver_later
  # end

  # before_transition to: :published do |execution|
  #   # Update publication timestamp
  #   execution.workflowable.update(published_at: Time.current)
  # end
end