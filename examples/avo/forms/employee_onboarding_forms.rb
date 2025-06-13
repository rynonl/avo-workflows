# frozen_string_literal: true

# Workflow forms for Employee Onboarding workflow actions
# These forms collect the rich data needed for each onboarding step

module EmployeeOnboardingForms
  # Form for collecting required documents during documentation review
  class CollectDocumentsForm < Avo::Workflows::Forms::Base
    title "Collect Required Documents"
    description "Specify which documents have been collected and reviewed"

    field :id_verification, as: :boolean, required: true, 
          label: "ID Verification", 
          help: "Government-issued photo ID verified"
          
    field :tax_forms, as: :boolean, required: true,
          label: "Tax Forms (W-4, I-9)",
          help: "All required tax and employment eligibility forms"
          
    field :emergency_contact, as: :boolean, required: true,
          label: "Emergency Contact Information",
          help: "Complete emergency contact details provided"
          
    field :direct_deposit, as: :boolean, required: false,
          label: "Direct Deposit Setup",
          help: "Banking information for payroll (optional)"
          
    field :benefits_enrollment, as: :boolean, required: false,
          label: "Benefits Enrollment",
          help: "Health, dental, vision, 401k enrollment completed"
          
    field :documentation_notes, as: :textarea, required: false,
          label: "Documentation Notes",
          help: "Additional notes about document collection"

    validates :id_verification, :tax_forms, :emergency_contact, 
              inclusion: { in: [true], message: "is required for onboarding" }
  end

  # Form for IT equipment assignment
  class AssignEquipmentForm < Avo::Workflows::Forms::Base
    title "Assign IT Equipment"
    description "Specify equipment assigned to the new employee"

    field :laptop_model, as: :select, required: true,
          label: "Laptop Model",
          options: ["MacBook Pro 14\"", "MacBook Pro 16\"", "MacBook Air 13\"", "ThinkPad X1", "ThinkPad T14"],
          help: "Select primary laptop for employee"
          
    field :laptop_serial, as: :text, required: true,
          label: "Laptop Serial Number",
          help: "Record laptop serial number for inventory"
          
    field :monitor_type, as: :select, required: false,
          label: "External Monitor",
          options: ["None", "Dell 24\" 1080p", "Dell 27\" 1440p", "LG 32\" 4K", "Apple Studio Display"],
          help: "External monitor assignment"
          
    field :phone_assignment, as: :select, required: false,
          label: "Company Phone",
          options: ["None", "iPhone 15", "iPhone 15 Pro", "Samsung Galaxy S24"],
          help: "Company phone if required for role"
          
    field :accessories, as: :textarea, required: false,
          label: "Additional Accessories",
          help: "List any additional equipment (keyboard, mouse, headphones, etc.)"
          
    field :software_licenses, as: :textarea, required: false,
          label: "Software Licenses",
          help: "List software licenses assigned (Adobe, Slack, etc.)"
          
    field :equipment_notes, as: :textarea, required: false,
          label: "Equipment Notes",
          help: "Additional notes about equipment assignment"

    validates :laptop_model, :laptop_serial, presence: true
  end

  # Form for training module assignment
  class AssignTrainingForm < Avo::Workflows::Forms::Base
    title "Assign Training Modules"
    description "Select required training modules based on role and department"

    field :company_orientation, as: :boolean, default: true,
          label: "Company Orientation",
          help: "General company culture, values, and policies"
          
    field :security_training, as: :boolean, default: true,
          label: "Security & Privacy Training", 
          help: "Information security, data privacy, and compliance"
          
    field :role_specific_training, as: :boolean, required: true,
          label: "Role-Specific Training",
          help: "Department and position-specific training modules"
          
    field :safety_training, as: :boolean, required: false,
          label: "Safety Training",
          help: "Workplace safety and emergency procedures"
          
    field :diversity_inclusion, as: :boolean, default: true,
          label: "Diversity & Inclusion Training",
          help: "Workplace diversity, inclusion, and harassment prevention"
          
    field :technical_training, as: :textarea, required: false,
          label: "Technical Training Requirements",
          help: "Specific technical skills or certifications needed"
          
    field :training_timeline, as: :select, required: true,
          label: "Training Timeline",
          options: ["1 week", "2 weeks", "30 days", "60 days", "90 days"],
          help: "Expected completion timeframe"
          
    field :trainer_assignment, as: :text, required: false,
          label: "Assigned Trainer/Mentor",
          help: "Name of trainer or mentor responsible for guidance"
          
    field :training_notes, as: :textarea, required: false,
          label: "Training Notes",
          help: "Additional training requirements or notes"
  end

  # Form for final approval with performance feedback
  class FinalApprovalForm < Avo::Workflows::Forms::Base
    title "Final Onboarding Approval"
    description "Complete final review and approve employee onboarding"

    field :documentation_complete, as: :boolean, required: true,
          label: "All Documentation Complete",
          help: "Verify all required documents are collected and processed"
          
    field :it_setup_verified, as: :boolean, required: true,
          label: "IT Setup Verified",
          help: "Confirm all IT equipment and accounts are working properly"
          
    field :training_completion, as: :boolean, required: true,
          label: "Training Requirements Met",
          help: "Verify employee has completed all required training"
          
    field :workspace_prepared, as: :boolean, required: true,
          label: "Workspace Prepared",
          help: "Physical workspace is ready and properly set up"
          
    field :manager_approval, as: :boolean, required: true,
          label: "Manager Approval",
          help: "Direct manager approves onboarding completion"
          
    field :hr_approval, as: :boolean, required: true,
          label: "HR Approval", 
          help: "HR representative approves onboarding completion"
          
    field :start_date_confirmed, as: :date, required: true,
          label: "Confirmed Start Date",
          help: "Official first day of employment"
          
    field :probation_period, as: :select, required: true,
          label: "Probation Period",
          options: ["30 days", "60 days", "90 days", "6 months", "None"],
          help: "Probationary period duration"
          
    field :performance_expectations, as: :textarea, required: false,
          label: "Performance Expectations",
          help: "Key performance indicators and expectations for first 90 days"
          
    field :approval_notes, as: :textarea, required: false,
          label: "Approval Notes",
          help: "Final comments or special instructions"

    validates :documentation_complete, :it_setup_verified, :training_completion, 
              :workspace_prepared, :manager_approval, :hr_approval,
              inclusion: { in: [true], message: "must be completed for final approval" }
              
    validates :start_date_confirmed, presence: true
  end

  # Form for rejection with detailed feedback
  class RejectOnboardingForm < Avo::Workflows::Forms::Base
    title "Reject Onboarding"
    description "Provide detailed feedback for onboarding rejection"

    field :rejection_category, as: :select, required: true,
          label: "Rejection Category",
          options: [
            "Documentation Issues",
            "Background Check Failed", 
            "Reference Check Failed",
            "Skills Assessment Failed",
            "Policy Violation",
            "Position No Longer Available",
            "Other"
          ],
          help: "Primary reason for rejection"
          
    field :detailed_reason, as: :textarea, required: true,
          label: "Detailed Reason",
          help: "Provide specific details about why onboarding is being rejected"
          
    field :documentation_issues, as: :textarea, required: false,
          label: "Documentation Issues",
          help: "Specific problems with submitted documents"
          
    field :background_check_notes, as: :textarea, required: false,
          label: "Background Check Notes", 
          help: "Issues found during background verification"
          
    field :reference_feedback, as: :textarea, required: false,
          label: "Reference Check Feedback",
          help: "Concerns raised during reference verification"
          
    field :skills_assessment_results, as: :textarea, required: false,
          label: "Skills Assessment Results",
          help: "Results of technical or skills evaluation"
          
    field :reapplication_allowed, as: :boolean, default: false,
          label: "Allow Future Reapplication",
          help: "Can this candidate reapply in the future?"
          
    field :reapplication_timeframe, as: :select, required: false,
          label: "Reapplication Timeframe",
          options: ["3 months", "6 months", "1 year", "2 years", "Never"],
          help: "When can candidate reapply (if allowed)"
          
    field :hr_notification_required, as: :boolean, default: true,
          label: "Notify HR Leadership",
          help: "Should HR leadership be notified of this rejection?"
          
    field :legal_review_required, as: :boolean, default: false,
          label: "Legal Review Required",
          help: "Does this rejection require legal department review?"

    validates :rejection_category, :detailed_reason, presence: true
  end
end

# Register forms with the Employee Onboarding workflow
if defined?(EmployeeOnboardingWorkflow)
  EmployeeOnboardingWorkflow.class_eval do
    include Avo::Workflows::Forms::WorkflowFormMethods

    action_form :collect_documents, EmployeeOnboardingForms::CollectDocumentsForm
    action_form :assign_equipment, EmployeeOnboardingForms::AssignEquipmentForm  
    action_form :assign_training, EmployeeOnboardingForms::AssignTrainingForm
    action_form :final_approval, EmployeeOnboardingForms::FinalApprovalForm
    action_form :reject_onboarding, EmployeeOnboardingForms::RejectOnboardingForm
  end
end