# frozen_string_literal: true

# Example: Issue Tracking Workflow
# Manages bug reports and feature requests through their lifecycle
class IssueTrackingWorkflow < Avo::Workflows::Base
  step :new do
    action :triage, to: :triaged
    action :reject, to: :rejected
    action :duplicate, to: :duplicate
  end

  step :triaged do
    action :assign, to: :assigned
    action :prioritize_high, to: :high_priority
    action :needs_info, to: :waiting_for_info
    action :reject, to: :rejected
  end

  step :waiting_for_info do
    action :info_provided, to: :triaged
    action :close_stale, to: :closed
  end

  step :assigned do
    action :start_work, to: :in_progress
    action :reassign, to: :triaged
    action :block, to: :blocked
  end

  step :high_priority do
    action :assign_urgent, to: :assigned
    action :escalate, to: :escalated
  end

  step :escalated do
    action :assign_senior, to: :assigned
    action :defer, to: :triaged
  end

  step :in_progress do
    action :submit_fix, to: :code_review
    action :block, to: :blocked
    action :needs_design, to: :design_review
  end

  step :blocked do
    action :unblock, to: :assigned
    action :escalate_block, to: :escalated
  end

  step :design_review do
    action :design_approved, to: :in_progress
    action :design_rejected, to: :assigned
  end

  step :code_review do
    action :approve_code, to: :testing
    action :request_changes, to: :in_progress
  end

  step :testing do
    action :pass_qa, to: :ready_for_release
    action :fail_qa, to: :in_progress
  end

  step :ready_for_release do
    action :deploy, to: :deployed
    action :hold_release, to: :testing
  end

  step :deployed do
    action :verify_fix, to: :resolved
    action :regression_found, to: :in_progress
  end

  step :resolved do
    action :reopen, to: :triaged
    action :close, to: :closed
  end

  step :rejected do
    action :reopen, to: :new
  end

  step :duplicate do
    action :reopen, to: :new
  end

  step :closed do
    action :reopen, to: :triaged
  end

  # Example conditions for different issue types
  # step :design_review do
  #   condition { context[:issue_type] == 'feature' }
  # end

  # step :security_review do
  #   condition { context[:security_impact] == true }
  # end
end