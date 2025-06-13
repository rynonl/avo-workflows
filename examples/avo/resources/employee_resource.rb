# frozen_string_literal: true

# Avo Resource for Employee with comprehensive workflow integration
# Demonstrates how to integrate workflow forms, actions, and displays
class EmployeeResource < Avo::BaseResource
  include Avo::Workflows::ResourceMethods

  self.title = :name
  self.includes = [:workflow_execution, :manager, :hr_representative]
  self.search_query = -> { query.where("name ILIKE ? OR email ILIKE ?", "%#{params[:q]}%", "%#{params[:q]}%") }

  # Basic employee fields
  field :name, as: :text, required: true
  field :email, as: :text, required: true
  field :employee_type, as: :select, 
        options: {
          "Full Time" => "full_time",
          "Contractor" => "contractor", 
          "Intern" => "intern",
          "Executive" => "executive"
        },
        required: true
  field :department, as: :text
  field :salary_level, as: :select,
        options: ["junior", "mid", "senior", "staff", "principal", "executive"]
  field :start_date, as: :date
  field :manager, as: :belongs_to, class: "User"
  field :hr_representative, as: :belongs_to, class: "User"

  # Workflow status fields  
  field :workflow_status, as: :workflow_progress,
        name: "Onboarding Status",
        show_on: [:show, :index],
        show_percentage: true,
        color_coding: true

  field :workflow_current_step, as: :text,
        name: "Current Step", 
        show_on: :index do |model|
          model.workflow_execution&.current_step&.humanize || "Not Started"
        end

  field :workflow_assigned_to, as: :text,
        name: "Assigned To",
        show_on: [:show, :index] do |model|
          model.workflow_execution&.assigned_user&.name || "Unassigned"
        end

  # Workflow action field with forms
  field :workflow_actions, as: :workflow_actions,
        name: "Available Actions",
        show_on: :show,
        confirm_dangerous: true,
        show_conditions: true

  # Workflow information panels
  panel :onboarding_workflow, as: :workflow_step_panel,
        name: "Onboarding Progress",
        show_on: :show do |panel|
    panel.show_step_details = true
    panel.show_assigned_users = true
    panel.show_estimated_completion = true
    panel.show_context_summary = true
  end

  panel :workflow_history, as: :workflow_history_panel,
        name: "Onboarding History", 
        show_on: :show do |panel|
    panel.show_context_changes = true
    panel.show_user_actions = true
    panel.show_system_events = true
    panel.items_per_page = 10
  end

  panel :workflow_context, as: :workflow_context_panel,
        name: "Onboarding Data",
        show_on: :show do |panel|
    panel.editable_fields = [:notes, :special_requirements]
    panel.readonly_fields = [:created_at, :system_data]
    panel.show_json_view = true
  end

  # Filters for workflow management
  filter :onboarding_status, as: :workflow_status_filter do |filter|
    filter.name = "Onboarding Status"
  end

  filter :current_step, as: :current_step_filter do |filter|
    filter.name = "Current Step"
    filter.dynamic_options = true
  end

  filter :employee_type, as: :select_filter,
         options: {
           "Full Time" => "full_time",
           "Contractor" => "contractor",
           "Intern" => "intern", 
           "Executive" => "executive"
         }

  filter :department, as: :text_filter
  filter :start_date, as: :date_range_filter

  # Workflow actions with forms
  action :start_onboarding_action, as: :workflow_action do |action|
    action.name = "Start Onboarding"
    action.icon = "heroicons/outline/play"
    action.message = "Onboarding workflow started successfully"
    action.visible = -> { !resource.workflow_execution&.active? }
  end

  # Document collection action with form
  action_for_workflow :collect_documents do |action|
    action.name = "Collect Documents"
    action.icon = "heroicons/outline/document-text"
    action.message = "Documents collected successfully"
    action.confirm_button_label = "Collect Documents"
  end

  # Equipment assignment action with form
  action_for_workflow :assign_equipment do |action|
    action.name = "Assign Equipment"
    action.icon = "heroicons/outline/computer-desktop"
    action.message = "Equipment assigned successfully"  
    action.confirm_button_label = "Assign Equipment"
  end

  # Training assignment action with form
  action_for_workflow :assign_training do |action|
    action.name = "Assign Training"
    action.icon = "heroicons/outline/academic-cap"
    action.message = "Training modules assigned successfully"
    action.confirm_button_label = "Assign Training"
  end

  # Final approval action with comprehensive form
  action_for_workflow :final_approval do |action|
    action.name = "Final Approval"
    action.icon = "heroicons/outline/check-badge"
    action.message = "Onboarding approved and completed"
    action.confirm_button_label = "Complete Onboarding"
    action.dangerous = false
  end

  # Rejection action with detailed form
  action_for_workflow :reject_onboarding do |action|
    action.name = "Reject Onboarding"
    action.icon = "heroicons/outline/x-circle"
    action.message = "Onboarding rejected"
    action.confirm_button_label = "Reject Onboarding"
    action.dangerous = true
    action.confirm_text = "Are you sure you want to reject this employee's onboarding? This action cannot be undone."
  end

  # Bulk actions for multiple employees
  action :bulk_start_onboarding do
    self.name = "Start Onboarding (Bulk)"
    self.standalone = false
    self.icon = "heroicons/outline/play"

    field :assigned_hr_rep, as: :belongs_to, 
          class: "User",
          help: "HR representative to assign to all selected employees"

    def handle(**args)
      models = args[:models]
      hr_rep = args[:fields][:assigned_hr_rep]

      success_count = 0
      models.each do |employee|
        next if employee.workflow_execution&.active?
        
        begin
          employee.start_onboarding!(assigned_to: hr_rep)
          success_count += 1
        rescue => e
          # Log error but continue with other employees
          Rails.logger.error "Failed to start onboarding for #{employee.name}: #{e.message}"
        end
      end

      if success_count > 0
        succeed "Started onboarding for #{success_count} employees"
      else
        error "Failed to start onboarding for any employees"
      end
    end
  end

  # Scopes for different workflow states
  scope :pending_onboarding, -> { left_joins(:workflow_execution).where(workflow_executions: { id: nil }) }
  scope :onboarding_in_progress, -> { joins(:workflow_execution).where(workflow_executions: { status: 'active' }) }
  scope :onboarding_completed, -> { joins(:workflow_execution).where(workflow_executions: { current_step: 'completed' }) }
  scope :onboarding_rejected, -> { joins(:workflow_execution).where(workflow_executions: { current_step: 'terminated' }) }

  # Computed fields for workflow insights
  field :onboarding_progress_percentage, as: :progress_bar,
        name: "Progress %",
        show_on: :index,
        max: 100 do |model|
    execution = model.workflow_execution
    return 0 unless execution

    # Calculate progress based on completed steps
    total_steps = 8 # Based on EmployeeOnboardingWorkflow steps
    current_step_number = step_number_for(execution.current_step)
    ((current_step_number.to_f / total_steps) * 100).round
  end

  field :days_in_onboarding, as: :number,
        name: "Days in Process",
        show_on: [:show, :index] do |model|
    execution = model.workflow_execution
    return 0 unless execution&.created_at
    
    (Date.current - execution.created_at.to_date).to_i
  end

  # Override Avo permissions based on workflow state
  def can_edit?
    # Allow editing basic info but not during active onboarding
    return true unless resource.workflow_execution&.active?
    
    # Only allow editing if user is assigned to the workflow
    current_user == resource.workflow_execution.assigned_user ||
    current_user.admin?
  end

  def can_delete?
    # Don't allow deletion of employees with active workflows
    !resource.workflow_execution&.active?
  end

  private

  # Helper method to create workflow actions with forms
  def self.action_for_workflow(action_name, &block)
    action_class = Avo::Workflows::Avo::Actions::WorkflowActionFactory.create_action(
      EmployeeOnboardingWorkflow,
      action_name
    )
    
    action action_name, action_class, &block
  end

  # Map workflow steps to numbers for progress calculation
  def step_number_for(step_name)
    step_mapping = {
      'initial_setup' => 1,
      'documentation_review' => 2,
      'it_provisioning' => 3,
      'training_assignment' => 4,
      'training_in_progress' => 5,
      'mentor_assignment' => 6,
      'executive_approval' => 7,
      'final_review' => 8,
      'completed' => 8,
      'terminated' => 0,
      'on_hold' => 0
    }
    
    step_mapping[step_name] || 0
  end
end