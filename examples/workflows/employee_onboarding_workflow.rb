# frozen_string_literal: true

# Example: Employee Onboarding Workflow
# Manages the complete employee onboarding process with multiple stakeholders
class EmployeeOnboardingWorkflow < Avo::Workflows::Base
  step :offer_extended do
    action :offer_accepted, to: :background_check
    action :offer_declined, to: :offer_declined
    action :offer_expired, to: :offer_expired
  end

  step :offer_declined do
    action :extend_new_offer, to: :offer_extended
  end

  step :offer_expired do
    action :extend_new_offer, to: :offer_extended
  end

  step :background_check do
    action :background_cleared, to: :pre_boarding
    action :background_failed, to: :background_failed
    action :background_pending, to: :background_check
  end

  step :background_failed do
    action :appeal_background, to: :background_check
    action :withdraw_offer, to: :offer_withdrawn
  end

  step :pre_boarding do
    action :paperwork_completed, to: :first_day_prep
    action :paperwork_incomplete, to: :pre_boarding
  end

  step :first_day_prep do
    action :equipment_ready, to: :day_one
    action :equipment_delayed, to: :first_day_prep
  end

  step :day_one do
    action :orientation_completed, to: :training_phase
    action :no_show, to: :no_show_followup
  end

  step :no_show_followup do
    action :employee_contacted, to: :day_one
    action :position_terminated, to: :terminated
  end

  step :training_phase do
    action :training_completed, to: :probation_period
    action :training_failed, to: :additional_training
    action :employee_quit, to: :terminated
  end

  step :additional_training do
    action :additional_training_completed, to: :probation_period
    action :training_unsuccessful, to: :performance_review
  end

  step :probation_period do
    action :probation_passed, to: :fully_onboarded
    action :probation_failed, to: :performance_review
    action :employee_quit, to: :terminated
  end

  step :performance_review do
    action :performance_improved, to: :probation_period
    action :terminate_employment, to: :terminated
  end

  step :fully_onboarded do
    # Successful completion
  end

  step :terminated do
    action :exit_interview_completed, to: :offboarded
  end

  step :offer_withdrawn do
    # Final state
  end

  step :offboarded do
    # Final state
  end

  # Example of conditional steps based on role
  # step :training_phase do
  #   condition { context[:department] != 'executive' }
  # end

  # step :executive_onboarding do
  #   condition { context[:department] == 'executive' }
  # end
end