# frozen_string_literal: true

# Advanced Employee Onboarding Workflow Example
#
# This comprehensive workflow demonstrates all advanced features of the avo-workflows system.
# It manages the complete employee onboarding process from initial setup through completion,
# with multiple branching paths, complex validations, and rich context management.
#
# Workflow Features Demonstrated:
# - Multiple branching paths based on employee type and conditions
# - Complex conditional logic with multiple validation methods
# - Rich context management with nested data structures  
# - Multiple user types and role-based permissions
# - Confirmation requirements for critical actions
# - Detailed requirements and comprehensive step descriptions
# - Error handling and robust validation
# - Multiple final states (completed, terminated, on_hold)
# - Self-transitions for iterative processes
# - Complex step dependencies and prerequisites
#
# Employee Types:
# - full_time: Standard employees with full benefits
# - contractor: Contract workers with limited access
# - intern: Student interns with mentorship requirements
# - executive: C-level executives with special procedures
#
# Workflow Steps:
# 1. initial_setup → HR creates employee record and assigns type
# 2. documentation_review → Manager reviews and approves documentation  
# 3. it_provisioning → IT sets up accounts and equipment
# 4. training_assignment → HR assigns role-specific training modules
# 5. training_in_progress → Employee completes assigned training
# 6. mentor_assignment → (Interns only) Assign and configure mentorship
# 7. executive_approval → (Executives only) Board approval process
# 8. final_review → Manager conducts final onboarding review
# 9. completed → Employee fully onboarded (final state)
# 10. terminated → Onboarding cancelled (final state)
# 11. on_hold → Process temporarily paused (final state)
#
# Usage:
#   # Create an employee
#   employee = Employee.create!(
#     name: "John Doe", 
#     email: "john@company.com",
#     employee_type: "full_time",
#     department: "Engineering"
#   )
#   
#   # Start onboarding workflow
#   execution = EmployeeOnboardingWorkflow.create_execution_for(
#     employee, 
#     assigned_to: hr_user,
#     initial_context: {
#       start_date: Date.current + 2.weeks,
#       salary_level: "senior",
#       security_clearance: "standard"
#     }
#   )
#   
#   # Progress through workflow
#   execution.perform_action(:begin_documentation_review, user: manager)
#   execution.perform_action(:approve_documentation, user: manager, 
#                           additional_context: { notes: "All documents verified" })

class EmployeeOnboardingWorkflow < Avo::Workflows::Base
  
  # Step 1: Initial Setup - HR creates employee record and basic information
  step :initial_setup do
    describe "HR representative sets up new employee record and determines onboarding path"
    
    requirement "Employee personal information must be complete"
    requirement "Employment type must be specified (full_time, contractor, intern, executive)"
    requirement "Department assignment must be confirmed"
    requirement "Start date must be set (minimum 3 days in future)"
    requirement "Manager assignment must be completed"
    
    # HR begins documentation collection process
    action :begin_documentation_review,
           to: :documentation_review,
           description: "Start documentation collection and review process",
           condition: ->(context) { basic_info_complete?(context) }
    
    # Emergency termination before start
    action :cancel_onboarding,
           to: :terminated,
           description: "Cancel onboarding process (emergency only)",
           confirmation_required: true
  end

  # Step 2: Documentation Review - Manager reviews all employment documents
  step :documentation_review do
    describe "Manager reviews and approves all employment documentation and contracts"
    
    requirement "All employment contracts must be signed"
    requirement "Background check must be completed and approved"
    requirement "Reference checks must be verified"
    requirement "Salary and benefits package must be finalized"
    requirement "Security clearance documentation (if required)"
    
    # Manager approves all documentation
    action :approve_documentation,
           to: :it_provisioning,
           description: "Approve all documentation and proceed to IT setup",
           condition: ->(context) { documentation_complete?(context) },
           confirmation_required: true
    
    # Request additional documentation
    action :request_additional_docs,
           to: :documentation_review,
           description: "Request additional or corrected documentation from employee"
    
    # Reject documentation and terminate
    action :reject_documentation,
           to: :terminated,
           description: "Reject documentation and terminate onboarding process",
           confirmation_required: true
  end

  # Step 3: IT Provisioning - IT department sets up accounts and equipment
  step :it_provisioning do
    describe "IT department provisions accounts, equipment, and system access for new employee"
    
    requirement "Email account must be created and configured"
    requirement "Hardware allocation must be completed (laptop, phone, etc.)"
    requirement "Software licenses must be assigned"
    requirement "Network access and VPN must be configured"
    requirement "Security software must be installed and configured"
    requirement "Department-specific system access must be granted"
    
    # IT completes all provisioning
    action :complete_it_setup,
           to: :training_assignment,
           description: "Mark IT provisioning as complete and ready for training",
           condition: ->(context) { it_setup_complete?(context) }
    
    # Request additional IT requirements
    action :request_additional_access,
           to: :it_provisioning,
           description: "Request additional system access or equipment"
    
    # IT setup failure - place on hold
    action :it_setup_failed,
           to: :on_hold,
           description: "IT setup failed - place onboarding on hold for resolution",
           confirmation_required: true
  end

  # Step 4: Training Assignment - HR assigns role and department specific training
  step :training_assignment do
    describe "HR assigns and configures role-specific training modules and learning paths"
    
    requirement "Role-specific training modules must be identified"
    requirement "Department orientation must be scheduled"
    requirement "Compliance training must be assigned"
    requirement "Safety training must be completed (if applicable)"
    requirement "Training timeline must be established"
    
    # Assign training and begin employee completion
    action :assign_training,
           to: :training_in_progress,
           description: "Assign all training modules and notify employee to begin",
           condition: ->(context) { training_modules_ready?(context) }
    
    # Special path for interns - requires mentor assignment
    action :assign_intern_training,
           to: :mentor_assignment,
           description: "Assign intern-specific training and proceed to mentor assignment",
           condition: ->(context) { employee_is_intern?(context) && training_modules_ready?(context) }
    
    # Special path for executives - requires board approval
    action :assign_executive_training,
           to: :executive_approval,
           description: "Assign executive training and proceed to board approval process",
           condition: ->(context) { employee_is_executive?(context) && training_modules_ready?(context) }
  end

  # Step 5: Training In Progress - Employee completes assigned training modules
  step :training_in_progress do
    describe "Employee actively completing assigned training modules and assessments"
    
    requirement "All assigned training modules must be completed"
    requirement "Training assessments must be passed with minimum scores"
    requirement "Attendance at mandatory sessions must be recorded"
    requirement "Training feedback must be collected"
    
    # Employee completes all training successfully
    action :complete_training,
           to: :final_review,
           description: "Mark all training as complete and proceed to final review",
           condition: ->(context) { all_training_complete?(context) }
    
    # Training needs additional time or modules
    action :extend_training,
           to: :training_in_progress,
           description: "Extend training period or assign additional modules"
    
    # Training failure - requires review
    action :training_failed,
           to: :on_hold,
           description: "Training requirements not met - place on hold for review",
           confirmation_required: true
  end

  # Step 6: Mentor Assignment - Special step for interns requiring mentorship setup
  step :mentor_assignment do
    describe "Assign mentor and configure mentorship program for intern onboarding"
    
    requirement "Qualified mentor must be identified and assigned"
    requirement "Mentorship goals and objectives must be established"
    requirement "Regular check-in schedule must be configured"
    requirement "Mentor training completion must be verified"
    requirement "Intern project assignment must be planned"
    
    # Mentor assigned successfully
    action :mentor_assigned,
           to: :training_in_progress,
           description: "Mentor successfully assigned - proceed with intern training",
           condition: ->(context) { mentor_assignment_complete?(context) }
    
    # Cannot find suitable mentor
    action :mentor_unavailable,
           to: :on_hold,
           description: "Unable to assign mentor - place intern onboarding on hold",
           confirmation_required: true
  end

  # Step 7: Executive Approval - Special step for executive-level hires
  step :executive_approval do
    describe "Board of directors approval process for executive-level appointments"
    
    requirement "Board presentation materials must be prepared"
    requirement "Executive compensation package must be approved"
    requirement "Public announcement strategy must be planned"
    requirement "Transition timeline must be established"
    requirement "Previous role transition must be managed"
    
    # Board approves executive appointment
    action :board_approval_granted,
           to: :training_in_progress,
           description: "Board approves executive appointment - proceed with training",
           condition: ->(context) { board_approval_received?(context) },
           confirmation_required: true
    
    # Board requests additional information
    action :board_requests_info,
           to: :executive_approval,
           description: "Board requests additional information before approval"
    
    # Board rejects executive appointment
    action :board_rejection,
           to: :terminated,
           description: "Board rejects executive appointment - terminate onboarding",
           confirmation_required: true
  end

  # Step 8: Final Review - Manager conducts comprehensive final review
  step :final_review do
    describe "Manager conducts final comprehensive review of onboarding completion"
    
    requirement "All previous steps must be verified as complete"
    requirement "Employee workspace must be prepared and ready"
    requirement "First day schedule must be planned and communicated"
    requirement "Team introductions must be arranged"
    requirement "Performance goals for first 90 days must be established"
    requirement "Onboarding feedback must be collected from employee"
    
    # Final review successful - complete onboarding
    action :approve_onboarding,
           to: :completed,
           description: "Approve final onboarding completion",
           condition: ->(context) { final_review_complete?(context) },
           confirmation_required: true
    
    # Issues found - return to appropriate step
    action :return_to_training,
           to: :training_in_progress,
           description: "Return to training for additional requirements"
    
    action :return_to_it,
           to: :it_provisioning,
           description: "Return to IT for additional provisioning"
    
    # Cancel at final stage
    action :cancel_final,
           to: :terminated,
           description: "Cancel onboarding at final review stage",
           confirmation_required: true
  end

  # Final State: Completed - Employee successfully onboarded
  step :completed do
    describe "Employee onboarding completed successfully - ready for first day"
    
    # No actions - this is a final state
    # In a real system, you might have post-onboarding actions like:
    # - schedule_90_day_review
    # - send_completion_notifications
    # - update_hr_systems
  end

  # Final State: Terminated - Onboarding process cancelled
  step :terminated do
    describe "Employee onboarding process cancelled or terminated"
    
    # No actions - this is a final state
    # In a real system, you might have cleanup actions like:
    # - revoke_system_access
    # - return_equipment
    # - update_records
  end

  # Final State: On Hold - Process temporarily paused
  step :on_hold do
    describe "Onboarding process temporarily paused pending resolution"
    
    # Resume onboarding from appropriate step
    action :resume_from_documentation,
           to: :documentation_review,
           description: "Resume onboarding from documentation review",
           condition: ->(context) { can_resume?(context) }
    
    action :resume_from_it,
           to: :it_provisioning,
           description: "Resume onboarding from IT provisioning",
           condition: ->(context) { can_resume?(context) }
    
    action :resume_from_training,
           to: :training_assignment,
           description: "Resume onboarding from training assignment",
           condition: ->(context) { can_resume?(context) }
    
    # Permanently cancel
    action :permanently_cancel,
           to: :terminated,
           description: "Permanently cancel onboarding process",
           confirmation_required: true
  end

  private

  # Validates that basic employee information is complete
  #
  # Checks that all required fields are present and valid for the employee
  # type, including conditional manager requirement for non-executives.
  #
  # @param context [Hash] workflow execution context containing employee data
  # @return [Boolean] true if basic info is complete
  # @example
  #   context = { 'workflowable' => employee.as_json }
  #   EmployeeOnboardingWorkflow.basic_info_complete?(context) #=> true
  def self.basic_info_complete?(context)
    employee_data = extract_employee_data(context)
    return false unless employee_data
    
    # Basic required fields for all employees
    basic_fields = %w[name email employee_type department start_date]
    basic_complete = basic_fields.all? { |field| employee_data[field].present? }
    
    # Manager is required for non-executives
    manager_required = if employee_data['employee_type'] == 'executive'
                         true
                       else
                         employee_data['manager_id'].present?
                       end
    
    basic_complete && manager_required && start_date_valid?(employee_data['start_date'])
  end

  # Validates that all required documentation is complete
  #
  # Verifies that employment contracts, background checks, and references
  # are approved, and benefits package has been finalized.
  #
  # @param context [Hash] workflow execution context containing documentation status
  # @return [Boolean] true if documentation is complete
  # @example
  #   context = { 'documentation' => { 'employment_contract' => 'approved' } }
  #   EmployeeOnboardingWorkflow.documentation_complete?(context) #=> false
  def self.documentation_complete?(context)
    docs = context['documentation'] || context[:documentation] || {}
    
    required_docs = %w[employment_contract background_check references]
    required_docs.all? { |doc| docs[doc] == 'approved' } &&
      benefits_finalized?(context)
  end

  # Validates that IT setup is complete
  #
  # Checks that all required IT provisioning items have been completed,
  # including email, hardware, software, network access, and security setup.
  #
  # @param context [Hash] workflow execution context containing IT status
  # @return [Boolean] true if IT setup is complete
  # @example
  #   context = { 'it_provisioning' => { 'email_account' => 'completed' } }
  #   EmployeeOnboardingWorkflow.it_setup_complete?(context) #=> false
  def self.it_setup_complete?(context)
    it_status = context['it_provisioning'] || context[:it_provisioning] || {}
    
    required_items = %w[
      email_account hardware software_licenses network_access security_setup
    ]
    required_items.all? { |item| it_status[item] == 'completed' }
  end

  # Validates that training modules are ready for assignment
  #
  # @param context [Hash] workflow execution context
  # @return [Boolean] true if training is ready
  def self.training_modules_ready?(context)
    employee_data = extract_employee_data(context)
    return false unless employee_data
    
    training_config = context['training_config'] || context[:training_config] || {}
    training_config['modules_assigned'].present? &&
    training_config['timeline_established'] == true
  end

  # Checks if employee is an intern
  #
  # @param context [Hash] workflow execution context
  # @return [Boolean] true if employee is intern
  def self.employee_is_intern?(context)
    employee_data = extract_employee_data(context)
    employee_data && employee_data['employee_type'] == 'intern'
  end

  # Checks if employee is an executive
  #
  # @param context [Hash] workflow execution context
  # @return [Boolean] true if employee is executive
  def self.employee_is_executive?(context)
    employee_data = extract_employee_data(context)
    employee_data && employee_data['employee_type'] == 'executive'
  end

  # Validates that all training is complete
  #
  # @param context [Hash] workflow execution context
  # @return [Boolean] true if all training complete
  def self.all_training_complete?(context)
    training_status = context['training_status'] || context[:training_status] || {}
    
    training_status['completion_percentage'] == 100 &&
      training_status['assessments_passed'] == true &&
      training_status['mandatory_sessions_attended'] == true
  end

  # Validates that mentor assignment is complete (for interns)
  #
  # @param context [Hash] workflow execution context  
  # @return [Boolean] true if mentor assigned
  def self.mentor_assignment_complete?(context)
    mentor_info = context['mentor_assignment'] || context[:mentor_assignment] || {}
    
    mentor_info['mentor_id'].present? &&
      mentor_info['goals_established'] == true &&
      mentor_info['schedule_configured'] == true
  end

  # Validates that board approval has been received (for executives)
  #
  # @param context [Hash] workflow execution context
  # @return [Boolean] true if board approved
  def self.board_approval_received?(context)
    approval_info = context['board_approval'] || context[:board_approval] || {}
    
    approval_info['status'] == 'approved' &&
    approval_info['approval_date'].present? &&
    approval_info['board_meeting_minutes'].present?
  end

  # Validates that final review is complete
  #
  # @param context [Hash] workflow execution context
  # @return [Boolean] true if final review complete
  def self.final_review_complete?(context)
    review_status = context['final_review'] || context[:final_review] || {}
    
    review_status['workspace_ready'] == true &&
    review_status['first_day_planned'] == true &&
    review_status['goals_established'] == true &&
    review_status['feedback_collected'] == true
  end

  # Determines if onboarding can be resumed from hold
  #
  # @param context [Hash] workflow execution context
  # @return [Boolean] true if can resume
  def self.can_resume?(context)
    hold_reason = context['hold_reason'] || context[:hold_reason]
    resolution_status = context['resolution_status'] || context[:resolution_status]
    
    hold_reason.present? && resolution_status == 'resolved'
  end

  # Validates that start date is appropriate (minimum 3 days in future)
  #
  # @param start_date [String, Date] the proposed start date
  # @return [Boolean] true if start date is valid
  def self.start_date_valid?(start_date)
    return false unless start_date
    
    date = start_date.is_a?(String) ? Date.parse(start_date) : start_date
    date >= Date.current + 3.days
  rescue ArgumentError
    false
  end

  # Validates that benefits package has been finalized
  #
  # @param context [Hash] workflow execution context
  # @return [Boolean] true if benefits finalized
  def self.benefits_finalized?(context)
    benefits = context['benefits_package'] || context[:benefits_package] || {}
    
    benefits['health_insurance'] == 'selected' &&
    benefits['retirement_plan'] == 'configured' &&
    benefits['pto_allocation'].present?
  end

  # Extracts employee data from context (handles both object and hash formats)
  #
  # @param context [Hash] workflow execution context
  # @return [Hash, nil] employee data hash or nil
  def self.extract_employee_data(context)
    workflowable = context['workflowable'] || context[:workflowable]
    return nil unless workflowable
    
    if workflowable.respond_to?(:attributes)
      workflowable.attributes
    elsif workflowable.is_a?(Hash)
      workflowable
    else
      nil
    end
  end
end