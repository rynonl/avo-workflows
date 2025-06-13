# frozen_string_literal: true

# Advanced Employee Model for Onboarding Workflow Integration
#
# This model demonstrates comprehensive workflow integration with complex business logic,
# multiple user types, rich context management, and sophisticated workflow orchestration.
#
# Employee Types:
# - full_time: Standard employees with full benefits and standard onboarding
# - contractor: Contract workers with limited access and simplified process  
# - intern: Student interns requiring mentorship and extended training
# - executive: C-level executives with board approval and special procedures
#
# Workflow Integration Features:
# - Rich initial context generation based on employee type and attributes
# - Context-aware workflow path selection 
# - Progress tracking and status reporting
# - Conditional workflow actions based on employee data
# - Multi-department coordination (HR, IT, Manager)
# - Complex validation and business rule enforcement

class Employee < ApplicationRecord
  # Employee type enumeration
  EMPLOYEE_TYPES = %w[full_time contractor intern executive].freeze
  
  # Department enumeration  
  DEPARTMENTS = %w[
    Engineering Marketing Sales HR Finance Operations 
    Legal Customer_Success Product Design Security
  ].freeze
  
  # Security clearance levels
  SECURITY_LEVELS = %w[none standard confidential secret top_secret].freeze
  
  # Associations
  belongs_to :manager, class_name: 'User', optional: true
  belongs_to :mentor, class_name: 'User', optional: true
  belongs_to :hr_representative, class_name: 'User', optional: true
  
  # The workflow execution tracks the onboarding process
  has_one :workflow_execution, 
          as: :workflowable, 
          class_name: 'Avo::Workflows::WorkflowExecution',
          dependent: :destroy

  # Validations
  validates :name, presence: true, length: { minimum: 2, maximum: 100 }
  validates :email, presence: true, uniqueness: true, 
                    format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :employee_type, presence: true, inclusion: { in: EMPLOYEE_TYPES }
  validates :department, presence: true, inclusion: { in: DEPARTMENTS }
  validates :security_clearance, inclusion: { in: SECURITY_LEVELS }, allow_blank: true
  validates :start_date, presence: true
  validates :salary_level, presence: true
  validates :employee_id, uniqueness: true, allow_blank: true
  
  # Custom validations
  validate :start_date_in_future
  validate :manager_required_for_non_executives
  validate :executive_validations
  validate :intern_validations
  
  # Scopes for different workflow states
  scope :pending_onboarding, -> { joins(:workflow_execution).where.not(avo_workflow_executions: { current_step: ['completed', 'terminated'] }) }
  scope :onboarding_complete, -> { joins(:workflow_execution).where(avo_workflow_executions: { current_step: 'completed' }) }
  scope :onboarding_terminated, -> { joins(:workflow_execution).where(avo_workflow_executions: { current_step: 'terminated' }) }
  scope :onboarding_on_hold, -> { joins(:workflow_execution).where(avo_workflow_executions: { current_step: 'on_hold' }) }
  
  # Scopes by employee type
  scope :full_time_employees, -> { where(employee_type: 'full_time') }
  scope :contractors, -> { where(employee_type: 'contractor') }
  scope :interns, -> { where(employee_type: 'intern') }
  scope :executives, -> { where(employee_type: 'executive') }
  
  # Scopes by department
  scope :engineering, -> { where(department: 'Engineering') }
  scope :sales, -> { where(department: 'Sales') }
  scope :marketing, -> { where(department: 'Marketing') }

  # Workflow state convenience methods
  
  # Gets current onboarding status in human-readable form
  # @return [String] current workflow step or status message
  def onboarding_status
    return 'Not started' unless workflow_execution
    
    step = workflow_execution.current_step
    case step
    when 'initial_setup' then 'Setting up employee record'
    when 'documentation_review' then 'Reviewing documentation'
    when 'it_provisioning' then 'Setting up IT access'
    when 'training_assignment' then 'Assigning training'
    when 'training_in_progress' then 'Completing training'
    when 'mentor_assignment' then 'Assigning mentor'
    when 'executive_approval' then 'Awaiting board approval'
    when 'final_review' then 'Final review in progress'
    when 'completed' then 'Onboarding complete'
    when 'terminated' then 'Onboarding cancelled'
    when 'on_hold' then 'Onboarding paused'
    else step.humanize
    end
  end

  # Checks if employee onboarding is complete
  # @return [Boolean] true if onboarding completed successfully
  def onboarding_complete?
    workflow_execution&.current_step == 'completed'
  end

  # Checks if employee onboarding is in progress
  # @return [Boolean] true if onboarding is active
  def onboarding_in_progress?
    return false unless workflow_execution
    !%w[completed terminated].include?(workflow_execution.current_step)
  end

  # Checks if employee is ready to start work
  # @return [Boolean] true if can start working
  def ready_to_start?
    onboarding_complete? || (contractor? && it_access_complete?)
  end

  # Employee type checks
  def full_time? = employee_type == 'full_time'
  def contractor? = employee_type == 'contractor'  
  def intern? = employee_type == 'intern'
  def executive? = employee_type == 'executive'

  # Security clearance checks
  def requires_security_clearance?
    !security_clearance.nil? && security_clearance != 'none'
  end
  def high_security_clearance? = %w[secret top_secret].include?(security_clearance)

  # Workflow Management
  
  # Starts the employee onboarding workflow with rich initial context
  #
  # @param assigned_to [User] the user to assign the workflow to (defaults to HR rep)
  # @param additional_context [Hash] extra context data to include
  # @return [Avo::Workflows::WorkflowExecution] the created workflow execution
  def start_onboarding!(assigned_to: nil, additional_context: {})
    return workflow_execution if workflow_execution.present?

    assigned_user = assigned_to || hr_representative || User.find_by(role: 'hr_admin')
    execution = EmployeeOnboardingWorkflow.create_execution_for(
      self,
      assigned_to: assigned_user,
      initial_context: build_initial_workflow_context.merge(additional_context)
    )
    
    # Reload to get the association
    reload
    execution
  end

  # Progresses to documentation review with manager validation
  #
  # @param manager [User] the manager to assign for review
  # @param notes [String] optional notes about the employee
  # @return [Boolean] true if action was successful
  def begin_documentation_review!(manager:, notes: nil)
    ensure_workflow_exists!
    
    # Update manager assignment if provided
    update!(manager: manager) if manager && self.manager != manager
    
    context = build_documentation_context(notes)
    workflow_execution.perform_action(:begin_documentation_review, 
                                      user: manager, 
                                      additional_context: context)
  end

  # Manager approves documentation and proceeds to IT
  #
  # @param manager [User] the manager approving documentation
  # @param documentation_notes [String] notes about documentation review
  # @return [Boolean] true if action was successful
  def approve_documentation!(manager:, documentation_notes: nil)
    ensure_workflow_exists!
    
    context = {
      documentation: build_approved_documentation_status,
      benefits_package: build_benefits_package,
      manager_approval_notes: documentation_notes,
      approved_by: manager.id,
      approval_timestamp: Time.current
    }
    
    workflow_execution.perform_action(:approve_documentation, 
                                      user: manager, 
                                      additional_context: context)
  end

  # IT completes system provisioning
  #
  # @param it_user [User] the IT staff member completing setup
  # @param equipment_details [Hash] details about allocated equipment
  # @return [Boolean] true if action was successful
  def complete_it_setup!(it_user:, equipment_details: {})
    ensure_workflow_exists!
    
    context = {
      it_provisioning: build_it_provisioning_status,
      equipment_allocated: equipment_details,
      it_completion_timestamp: Time.current,
      completed_by_it: it_user.id
    }
    
    workflow_execution.perform_action(:complete_it_setup, 
                                      user: it_user, 
                                      additional_context: context)
  end

  # Assigns training modules based on employee type and role
  #
  # @param hr_user [User] the HR user assigning training
  # @param custom_modules [Array] additional training modules to assign
  # @return [Boolean] true if action was successful
  def assign_training!(hr_user:, custom_modules: [])
    ensure_workflow_exists!
    
    # Determine appropriate training path
    action = if intern?
      :assign_intern_training
    elsif executive?
      :assign_executive_training  
    else
      :assign_training
    end
    
    context = {
      training_config: build_training_configuration(custom_modules),
      assigned_by: hr_user.id,
      assignment_timestamp: Time.current
    }
    
    workflow_execution.perform_action(action, 
                                      user: hr_user, 
                                      additional_context: context)
  end

  # Marks training as complete and proceeds to final review
  #
  # @param employee_user [User] the employee completing training
  # @param training_feedback [String] employee feedback on training
  # @return [Boolean] true if action was successful
  def complete_training!(employee_user:, training_feedback: nil)
    ensure_workflow_exists!
    
    context = {
      training_status: build_training_completion_status,
      employee_feedback: training_feedback,
      completion_timestamp: Time.current,
      completed_by_employee: employee_user.id
    }
    
    workflow_execution.perform_action(:complete_training, 
                                      user: employee_user, 
                                      additional_context: context)
  end

  # Assigns mentor for intern onboarding
  #
  # @param mentor_user [User] the mentor to assign
  # @param hr_user [User] the HR user making the assignment
  # @param mentorship_goals [Array] goals for the mentorship
  # @return [Boolean] true if action was successful
  def assign_mentor!(mentor_user:, hr_user:, mentorship_goals: [])
    ensure_workflow_exists!
    return false unless intern?
    
    update!(mentor: mentor_user)
    
    # Update context first so condition can evaluate properly
    context = {
      mentor_assignment: {
        mentor_id: mentor_user.id,
        goals_established: true,
        schedule_configured: true,
        mentorship_goals: mentorship_goals,
        assignment_date: Date.current
      }
    }
    
    workflow_execution.update_context!(context)
    
    # Now perform the action
    workflow_execution.perform_action(:mentor_assigned, user: hr_user)
  end

  # Board approval for executive hires
  #
  # @param board_member [User] board member granting approval
  # @param meeting_minutes [String] reference to board meeting
  # @return [Boolean] true if action was successful
  def grant_board_approval!(board_member:, meeting_minutes:)
    ensure_workflow_exists!
    return false unless executive?
    
    # Update context first so condition can evaluate properly
    context = {
      board_approval: {
        status: 'approved',
        approval_date: Date.current,
        board_meeting_minutes: meeting_minutes,
        approved_by: board_member.id
      }
    }
    
    workflow_execution.update_context!(context)
    
    # Now perform the action
    workflow_execution.perform_action(:board_approval_granted, user: board_member)
  end

  # Final approval to complete onboarding
  #
  # @param manager [User] the manager conducting final review
  # @param workspace_ready [Boolean] whether workspace is prepared
  # @param goals_established [Boolean] whether 90-day goals are set
  # @return [Boolean] true if action was successful
  def approve_final_onboarding!(manager:, workspace_ready: true, goals_established: true)
    ensure_workflow_exists!
    
    context = {
      final_review: {
        workspace_ready: workspace_ready,
        first_day_planned: true,
        goals_established: goals_established,
        feedback_collected: true,
        final_approval_date: Date.current,
        approved_by_manager: manager.id
      }
    }
    
    workflow_execution.perform_action(:approve_onboarding, 
                                      user: manager, 
                                      additional_context: context)
  end

  # Gets available workflow actions for current step
  #
  # @return [Array<Symbol>] available action names
  def available_onboarding_actions
    return [] unless workflow_execution
    workflow_execution.available_actions
  end

  # Gets onboarding history for display
  #
  # @return [Array<Hash>] formatted history entries
  def onboarding_history
    return [] unless workflow_execution
    workflow_execution.step_history || []
  end

  # Gets workflow progress percentage
  #
  # @return [Integer] progress percentage (0-100)
  def onboarding_progress_percentage
    return 0 unless workflow_execution
    
    step_order = %w[initial_setup documentation_review it_provisioning training_assignment 
                   training_in_progress mentor_assignment executive_approval final_review completed]
    current_step = workflow_execution.current_step
    
    return 100 if current_step == 'completed'
    return 0 if %w[terminated on_hold].include?(current_step)
    
    current_index = step_order.index(current_step) || 0
    (current_index.to_f / (step_order.length - 1) * 100).round
  end

  private

  # Ensures workflow exists, creating it if necessary
  def ensure_workflow_exists!
    start_onboarding! unless workflow_execution.present?
  end

  # Builds comprehensive initial context for workflow
  # @return [Hash] initial context data
  def build_initial_workflow_context
    {
      workflowable: self,
      employee_name: name,
      employee_type: employee_type,
      department: department,
      start_date: start_date,
      manager_id: manager_id,
      security_clearance: security_clearance,
      salary_level: salary_level,
      requires_mentor: intern?,
      requires_board_approval: executive?,
      high_security: high_security_clearance?,
      workflow_started_at: Time.current,
      estimated_completion: calculate_estimated_completion_date
    }
  end

  # Builds documentation context for workflow transitions
  # @param notes [String] optional notes
  # @return [Hash] documentation context
  def build_documentation_context(notes)
    {
      documentation_review_started: Time.current,
      manager_notes: notes,
      security_clearance_required: requires_security_clearance?,
      employee_type_context: employee_type
    }
  end

  # Builds approved documentation status
  # @return [Hash] documentation approval status
  def build_approved_documentation_status
    {
      employment_contract: 'approved',
      background_check: 'approved', 
      references: 'approved',
      security_clearance_docs: requires_security_clearance? ? 'approved' : 'not_required'
    }
  end

  # Builds benefits package configuration
  # @return [Hash] benefits package details
  def build_benefits_package
    return { contractor_benefits: 'not_applicable' } if contractor?
    
    {
      health_insurance: 'selected',
      retirement_plan: 'configured',
      pto_allocation: calculate_pto_allocation,
      additional_benefits: determine_additional_benefits
    }
  end

  # Builds IT provisioning status
  # @return [Hash] IT setup completion status
  def build_it_provisioning_status
    {
      email_account: 'completed',
      hardware: 'completed',
      software_licenses: 'completed',
      network_access: 'completed',
      security_setup: 'completed',
      department_access: 'completed'
    }
  end

  # Builds training configuration based on employee type and role
  # @param custom_modules [Array] additional training modules
  # @return [Hash] training configuration
  def build_training_configuration(custom_modules = [])
    base_modules = %w[company_orientation safety_training compliance_basics]
    type_specific = training_modules_for_type
    department_specific = training_modules_for_department
    
    {
      modules_assigned: (base_modules + type_specific + department_specific + custom_modules).uniq,
      timeline_established: true,
      estimated_duration: calculate_training_duration,
      mandatory_sessions: determine_mandatory_sessions
    }
  end

  # Builds training completion status
  # @return [Hash] training completion details
  def build_training_completion_status
    {
      completion_percentage: 100,
      assessments_passed: true,
      mandatory_sessions_attended: true,
      completion_date: Date.current,
      certificates_earned: determine_certificates_earned
    }
  end

  # Validation methods
  
  def start_date_in_future
    return unless start_date
    
    if start_date <= Date.current + 2.days
      errors.add(:start_date, 'must be at least 3 days in the future')
    end
  end

  def manager_required_for_non_executives
    return if executive? || manager.present?
    errors.add(:manager, 'is required for non-executive employees')
  end

  def executive_validations
    return unless executive?
    
    errors.add(:salary_level, 'must be executive level') unless %w[executive c_level].include?(salary_level)
  end

  def intern_validations
    return unless intern?
    
    if start_date && start_date > Date.current + 6.months
      errors.add(:start_date, 'for interns should be within 6 months')
    end
  end

  # Helper methods for context building
  
  def calculate_estimated_completion_date
    base_days = case employee_type
    when 'contractor' then 7
    when 'intern' then 21
    when 'executive' then 28
    else 14
    end
    
    start_date + base_days.days
  end

  def calculate_pto_allocation
    case salary_level
    when 'junior' then 15
    when 'mid' then 20
    when 'senior' then 25
    when 'executive', 'c_level' then 30
    else 20
    end
  end

  def determine_additional_benefits
    benefits = []
    benefits << 'stock_options' if %w[senior executive c_level].include?(salary_level)
    benefits << 'flexible_schedule' if department == 'Engineering'
    benefits << 'professional_development' unless contractor?
    benefits
  end

  def training_modules_for_type
    case employee_type
    when 'contractor' then %w[contractor_guidelines project_specific]
    when 'intern' then %w[mentorship_program academic_credit project_assignment]
    when 'executive' then %w[leadership_training board_relations strategic_planning]
    else %w[benefits_overview career_development performance_management]
    end
  end

  def training_modules_for_department
    case department
    when 'Engineering' then %w[technical_stack code_review security_practices]
    when 'Sales' then %w[crm_training sales_methodology customer_relations]
    when 'Marketing' then %w[brand_guidelines marketing_tools campaign_management]
    when 'HR' then %w[employment_law diversity_inclusion payroll_systems]
    else %w[department_overview tools_training]
    end
  end

  def calculate_training_duration
    base_hours = case employee_type
    when 'contractor' then 8
    when 'intern' then 40
    when 'executive' then 16
    else 24
    end
    
    "#{base_hours} hours"
  end

  def determine_mandatory_sessions
    sessions = %w[company_all_hands safety_briefing]
    sessions << 'security_briefing' if high_security_clearance?
    sessions << 'leadership_orientation' if executive?
    sessions << 'intern_orientation' if intern?
    sessions
  end

  def determine_certificates_earned
    certs = %w[safety_certification compliance_certificate]
    certs << 'security_clearance_certificate' if requires_security_clearance?
    certs << 'leadership_certificate' if executive?
    certs
  end

  def it_access_complete?
    # Simplified check for contractors who may not need full onboarding
    workflow_execution&.context_data&.dig('it_provisioning', 'email_account') == 'completed'
  end
end