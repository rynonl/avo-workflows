# frozen_string_literal: true

require 'rails_helper'

RSpec.describe EmployeeOnboardingWorkflow, type: :workflow do
  # Test data setup with multiple user types
  let(:hr_user) { User.create!(name: 'HR Manager', email: 'hr@company.com') }
  let(:manager) { User.create!(name: 'Engineering Manager', email: 'manager@company.com') }
  let(:it_user) { User.create!(name: 'IT Admin', email: 'it@company.com') }
  let(:mentor) { User.create!(name: 'Senior Engineer', email: 'mentor@company.com') }
  let(:board_member) { User.create!(name: 'Board Chair', email: 'board@company.com') }
  let(:employee_user) { User.create!(name: 'New Employee', email: 'newbie@company.com') }

  # Different employee types for testing branching paths
  let(:full_time_employee) do
    Employee.create!(
      name: 'John Doe',
      email: 'john@company.com',
      employee_type: 'full_time',
      department: 'Engineering',
      salary_level: 'senior',
      start_date: Date.current + 1.week,
      manager: manager,
      hr_representative: hr_user
    )
  end

  let(:intern_employee) do
    Employee.create!(
      name: 'Jane Smith',
      email: 'jane@company.com',
      employee_type: 'intern',
      department: 'Engineering',
      salary_level: 'junior',
      start_date: Date.current + 2.weeks,
      manager: manager,
      hr_representative: hr_user
    )
  end

  let(:executive_employee) do
    Employee.create!(
      name: 'Executive Leader',
      email: 'exec@company.com',
      employee_type: 'executive',
      department: 'Operations',
      salary_level: 'c_level',
      start_date: Date.current + 1.month,
      hr_representative: hr_user
    )
  end

  let(:contractor_employee) do
    Employee.create!(
      name: 'Contract Worker',
      email: 'contractor@company.com',
      employee_type: 'contractor',
      department: 'Marketing',
      salary_level: 'mid',
      start_date: Date.current + 3.days,
      manager: manager,
      hr_representative: hr_user
    )
  end

  describe 'workflow definition' do
    it 'has the correct steps defined' do
      expected_steps = [
        :initial_setup, :documentation_review, :it_provisioning, :training_assignment,
        :training_in_progress, :mentor_assignment, :executive_approval, :final_review,
        :completed, :terminated, :on_hold
      ]
      expect(EmployeeOnboardingWorkflow.step_names).to eq(expected_steps)
    end

    it 'identifies correct initial step' do
      expect(EmployeeOnboardingWorkflow.initial_step).to eq(:initial_setup)
    end

    it 'identifies correct final steps' do
      expect(EmployeeOnboardingWorkflow.final_steps).to contain_exactly(:completed, :terminated)
    end

    it 'passes workflow validation' do
      errors = EmployeeOnboardingWorkflow.validate_definition
      expect(errors).to be_empty
    end
  end

  describe 'step definitions' do
    describe 'initial_setup step' do
      let(:initial_step) { EmployeeOnboardingWorkflow.find_step(:initial_setup) }

      it 'has comprehensive requirements' do
        expect(initial_step.requirements).to include(
          'Employee personal information must be complete',
          'Employment type must be specified (full_time, contractor, intern, executive)',
          'Department assignment must be confirmed'
        )
      end

      it 'has appropriate actions' do
        expect(initial_step.actions.keys).to contain_exactly(:begin_documentation_review, :cancel_onboarding)
      end

      it 'begin_documentation_review has condition and leads to documentation_review' do
        action = initial_step.actions[:begin_documentation_review]
        expect(action[:to]).to eq(:documentation_review)
        expect(action[:condition]).to be_a(Proc)
      end

      it 'cancel_onboarding requires confirmation' do
        expect(initial_step.confirmation_required?(:cancel_onboarding)).to be true
      end
    end

    describe 'training_assignment step' do
      let(:training_step) { EmployeeOnboardingWorkflow.find_step(:training_assignment) }

      it 'has branching actions for different employee types' do
        expect(training_step.actions.keys).to contain_exactly(
          :assign_training, :assign_intern_training, :assign_executive_training
        )
      end

      it 'intern action leads to mentor_assignment' do
        action = training_step.actions[:assign_intern_training]
        expect(action[:to]).to eq(:mentor_assignment)
      end

      it 'executive action leads to executive_approval' do
        action = training_step.actions[:assign_executive_training]
        expect(action[:to]).to eq(:executive_approval)
      end
    end

    describe 'on_hold step (resumable final state)' do
      let(:hold_step) { EmployeeOnboardingWorkflow.find_step(:on_hold) }

      it 'allows resumption from multiple points' do
        expect(hold_step.actions.keys).to include(
          :resume_from_documentation, :resume_from_it, :resume_from_training, :permanently_cancel
        )
      end

      it 'all resume actions have conditions' do
        resume_actions = [:resume_from_documentation, :resume_from_it, :resume_from_training]
        resume_actions.each do |action|
          expect(hold_step.actions[action][:condition]).to be_a(Proc)
        end
      end
    end
  end

  describe 'complex validation methods' do
    describe '.basic_info_complete?' do
      it 'returns true for complete employee data' do
        context = { 'workflowable' => full_time_employee.as_json }
        expect(EmployeeOnboardingWorkflow.send(:basic_info_complete?, context)).to be true
      end

      it 'returns false for incomplete employee data' do
        incomplete_employee = full_time_employee.as_json
        incomplete_employee['manager_id'] = nil
        context = { 'workflowable' => incomplete_employee }
        expect(EmployeeOnboardingWorkflow.send(:basic_info_complete?, context)).to be false
      end

      it 'validates start date is in future' do
        past_employee = full_time_employee.as_json
        past_employee['start_date'] = Date.current - 1.day
        context = { 'workflowable' => past_employee }
        expect(EmployeeOnboardingWorkflow.send(:basic_info_complete?, context)).to be false
      end
    end

    describe '.employee_is_intern?' do
      it 'correctly identifies intern employees' do
        context = { 'workflowable' => intern_employee.as_json }
        expect(EmployeeOnboardingWorkflow.send(:employee_is_intern?, context)).to be true
      end

      it 'returns false for non-intern employees' do
        context = { 'workflowable' => full_time_employee.as_json }
        expect(EmployeeOnboardingWorkflow.send(:employee_is_intern?, context)).to be false
      end
    end

    describe '.employee_is_executive?' do
      it 'correctly identifies executive employees' do
        context = { 'workflowable' => executive_employee.as_json }
        expect(EmployeeOnboardingWorkflow.send(:employee_is_executive?, context)).to be true
      end

      it 'returns false for non-executive employees' do
        context = { 'workflowable' => contractor_employee.as_json }
        expect(EmployeeOnboardingWorkflow.send(:employee_is_executive?, context)).to be false
      end
    end

    describe '.documentation_complete?' do
      it 'returns true when all documentation is approved' do
        context = {
          'documentation' => {
            'employment_contract' => 'approved',
            'background_check' => 'approved',
            'references' => 'approved'
          },
          'benefits_package' => {
            'health_insurance' => 'selected',
            'retirement_plan' => 'configured',
            'pto_allocation' => 20
          }
        }
        expect(EmployeeOnboardingWorkflow.send(:documentation_complete?, context)).to be true
      end

      it 'returns false when documentation is incomplete' do
        context = {
          'documentation' => {
            'employment_contract' => 'pending',
            'background_check' => 'approved',
            'references' => 'approved'
          }
        }
        expect(EmployeeOnboardingWorkflow.send(:documentation_complete?, context)).to be false
      end
    end

    describe '.it_setup_complete?' do
      it 'returns true when all IT items are completed' do
        context = {
          'it_provisioning' => {
            'email_account' => 'completed',
            'hardware' => 'completed',
            'software_licenses' => 'completed',
            'network_access' => 'completed',
            'security_setup' => 'completed'
          }
        }
        expect(EmployeeOnboardingWorkflow.send(:it_setup_complete?, context)).to be true
      end

      it 'returns false when IT setup is incomplete' do
        context = {
          'it_provisioning' => {
            'email_account' => 'completed',
            'hardware' => 'pending',
            'software_licenses' => 'completed',
            'network_access' => 'completed',
            'security_setup' => 'completed'
          }
        }
        expect(EmployeeOnboardingWorkflow.send(:it_setup_complete?, context)).to be false
      end
    end
  end

  describe 'workflow execution' do
    let(:workflow_execution) { full_time_employee.start_onboarding!(assigned_to: hr_user) }

    describe 'initial state' do
      it 'starts in initial_setup step' do
        expect(workflow_execution.current_step).to eq('initial_setup')
      end

      it 'is assigned to HR user' do
        expect(workflow_execution.assigned_to).to eq(hr_user)
      end

      it 'has rich initial context' do
        context = workflow_execution.context_data
        expect(context['employee_name']).to eq('John Doe')
        expect(context['employee_type']).to eq('full_time')
        expect(context['department']).to eq('Engineering')
        expect(context['requires_mentor']).to be false
        expect(context['requires_board_approval']).to be false
      end
    end

    describe 'full_time employee workflow path' do
      before do
        # Set up complete context for full workflow
        workflow_execution.update_context!({
          'documentation' => {
            'employment_contract' => 'approved',
            'background_check' => 'approved', 
            'references' => 'approved'
          },
          'benefits_package' => {
            'health_insurance' => 'selected',
            'retirement_plan' => 'configured',
            'pto_allocation' => 20
          },
          'it_provisioning' => {
            'email_account' => 'completed',
            'hardware' => 'completed',
            'software_licenses' => 'completed',
            'network_access' => 'completed',
            'security_setup' => 'completed'
          },
          'training_config' => {
            'modules_assigned' => ['orientation', 'compliance'],
            'timeline_established' => true
          },
          'training_status' => {
            'completion_percentage' => 100,
            'assessments_passed' => true,
            'mandatory_sessions_attended' => true
          },
          'final_review' => {
            'workspace_ready' => true,
            'first_day_planned' => true,
            'goals_established' => true,
            'feedback_collected' => true
          }
        })
      end

      it 'progresses through standard workflow steps' do
        # Initial setup → Documentation review
        expect(workflow_execution.perform_action(:begin_documentation_review, user: hr_user)).to be true
        expect(workflow_execution.current_step).to eq('documentation_review')

        # Documentation review → IT provisioning
        expect(workflow_execution.perform_action(:approve_documentation, user: manager)).to be true
        expect(workflow_execution.current_step).to eq('it_provisioning')

        # IT provisioning → Training assignment
        expect(workflow_execution.perform_action(:complete_it_setup, user: it_user)).to be true
        expect(workflow_execution.current_step).to eq('training_assignment')

        # Training assignment → Training in progress (standard path)
        expect(workflow_execution.perform_action(:assign_training, user: hr_user)).to be true
        expect(workflow_execution.current_step).to eq('training_in_progress')

        # Training completion → Final review
        expect(workflow_execution.perform_action(:complete_training, user: employee_user)).to be true
        expect(workflow_execution.current_step).to eq('final_review')

        # Final review → Completed
        expect(workflow_execution.perform_action(:approve_onboarding, user: manager)).to be true
        expect(workflow_execution.current_step).to eq('completed')
        expect(workflow_execution.status).to eq('completed')
      end
    end

    describe 'intern workflow path with mentor assignment' do
      let(:intern_execution) { intern_employee.start_onboarding!(assigned_to: hr_user) }

      before do
        # Set up context for intern workflow
        intern_execution.update_context!({
          'documentation' => {
            'employment_contract' => 'approved',
            'background_check' => 'approved',
            'references' => 'approved'
          },
          'benefits_package' => {
            'health_insurance' => 'selected',
            'retirement_plan' => 'configured',
            'pto_allocation' => 15
          },
          'it_provisioning' => {
            'email_account' => 'completed',
            'hardware' => 'completed',
            'software_licenses' => 'completed',
            'network_access' => 'completed',
            'security_setup' => 'completed'
          },
          'training_config' => {
            'modules_assigned' => ['intern_orientation', 'mentorship_program'],
            'timeline_established' => true
          },
          'mentor_assignment' => {
            'mentor_id' => mentor.id,
            'goals_established' => true,
            'schedule_configured' => true
          },
          'training_status' => {
            'completion_percentage' => 100,
            'assessments_passed' => true,
            'mandatory_sessions_attended' => true
          },
          'final_review' => {
            'workspace_ready' => true,
            'first_day_planned' => true,
            'goals_established' => true,
            'feedback_collected' => true
          }
        })
      end

      it 'follows intern-specific workflow path' do
        # Progress to training assignment
        intern_execution.perform_action(:begin_documentation_review, user: hr_user)
        intern_execution.perform_action(:approve_documentation, user: manager)
        intern_execution.perform_action(:complete_it_setup, user: it_user)

        # Intern-specific training assignment → Mentor assignment
        expect(intern_execution.perform_action(:assign_intern_training, user: hr_user)).to be true
        expect(intern_execution.current_step).to eq('mentor_assignment')

        # Mentor assignment → Training in progress
        expect(intern_execution.perform_action(:mentor_assigned, user: hr_user)).to be true
        expect(intern_execution.current_step).to eq('training_in_progress')

        # Complete workflow
        intern_execution.perform_action(:complete_training, user: employee_user)
        expect(intern_execution.perform_action(:approve_onboarding, user: manager)).to be true
        expect(intern_execution.current_step).to eq('completed')
      end
    end

    describe 'executive workflow path with board approval' do
      let(:exec_execution) { executive_employee.start_onboarding!(assigned_to: hr_user) }

      before do
        # Set up context for executive workflow
        exec_execution.update_context!({
          'documentation' => {
            'employment_contract' => 'approved',
            'background_check' => 'approved',
            'references' => 'approved'
          },
          'benefits_package' => {
            'health_insurance' => 'selected',
            'retirement_plan' => 'configured',
            'pto_allocation' => 30
          },
          'it_provisioning' => {
            'email_account' => 'completed',
            'hardware' => 'completed',
            'software_licenses' => 'completed',
            'network_access' => 'completed',
            'security_setup' => 'completed'
          },
          'training_config' => {
            'modules_assigned' => ['executive_orientation', 'leadership_training'],
            'timeline_established' => true
          },
          'board_approval' => {
            'status' => 'approved',
            'approval_date' => Date.current,
            'board_meeting_minutes' => 'Executive approved unanimously'
          },
          'training_status' => {
            'completion_percentage' => 100,
            'assessments_passed' => true,
            'mandatory_sessions_attended' => true
          },
          'final_review' => {
            'workspace_ready' => true,
            'first_day_planned' => true,
            'goals_established' => true,
            'feedback_collected' => true
          }
        })
      end

      it 'follows executive-specific workflow path' do
        # Progress to training assignment
        exec_execution.perform_action(:begin_documentation_review, user: hr_user)
        exec_execution.perform_action(:approve_documentation, user: manager)
        exec_execution.perform_action(:complete_it_setup, user: it_user)

        # Executive-specific training assignment → Board approval
        expect(exec_execution.perform_action(:assign_executive_training, user: hr_user)).to be true
        expect(exec_execution.current_step).to eq('executive_approval')

        # Board approval → Training in progress
        expect(exec_execution.perform_action(:board_approval_granted, user: board_member)).to be true
        expect(exec_execution.current_step).to eq('training_in_progress')

        # Complete workflow
        exec_execution.perform_action(:complete_training, user: employee_user)
        expect(exec_execution.perform_action(:approve_onboarding, user: manager)).to be true
        expect(exec_execution.current_step).to eq('completed')
      end
    end
  end

  describe 'error handling and edge cases' do
    let(:workflow_execution) { full_time_employee.start_onboarding!(assigned_to: hr_user) }

    it 'handles invalid actions gracefully' do
      success = workflow_execution.perform_action(:invalid_action, user: hr_user)
      expect(success).to be false
      expect(workflow_execution.current_step).to eq('initial_setup')
    end

    it 'prevents transitions when conditions are not met' do
      # Create executive with past start date (which should fail the condition)
      past_date_employee = Employee.new(
        name: 'Past Date Employee',
        email: 'pastdate@company.com',
        employee_type: 'executive',
        department: 'Operations',
        salary_level: 'c_level',
        start_date: Date.current - 1.day, # Past date should fail validation
        hr_representative: hr_user
      )
      past_date_employee.save(validate: false) # Bypass validation for test
      incomplete_execution = past_date_employee.start_onboarding!(assigned_to: hr_user)
      
      # Try to begin documentation review without complete info
      success = incomplete_execution.perform_action(:begin_documentation_review, user: hr_user)
      expect(success).to be false
      expect(incomplete_execution.current_step).to eq('initial_setup')
    end

    it 'allows emergency cancellation at any step' do
      # Progress to documentation review step
      workflow_execution.update_context!({
        'documentation' => {
          'employment_contract' => 'approved',
          'background_check' => 'approved',
          'references' => 'approved'
        },
        'benefits_package' => {
          'health_insurance' => 'selected',
          'retirement_plan' => 'configured',
          'pto_allocation' => 20
        }
      })

      workflow_execution.perform_action(:begin_documentation_review, user: hr_user)
      
      # Emergency cancellation from documentation_review step
      expect(workflow_execution.perform_action(:reject_documentation, user: manager)).to be true
      expect(workflow_execution.current_step).to eq('terminated')
    end

    it 'supports resumption from on_hold state' do
      # Put workflow on hold
      workflow_execution.perform_action(:cancel_onboarding, user: hr_user)
      workflow_execution.update!(current_step: 'on_hold')
      workflow_execution.update_context!({
        'hold_reason' => 'Missing documents',
        'resolution_status' => 'resolved'
      })

      # Resume from documentation
      expect(workflow_execution.perform_action(:resume_from_documentation, user: hr_user)).to be true
      expect(workflow_execution.current_step).to eq('documentation_review')
    end
  end

  describe 'context management' do
    let(:workflow_execution) { full_time_employee.start_onboarding!(assigned_to: hr_user) }

    it 'preserves complex context across transitions' do
      initial_context = workflow_execution.context_data.dup
      
      additional_data = {
        'custom_field' => 'custom_value',
        'nested_data' => {
          'level1' => {
            'level2' => 'deep_value'
          }
        }
      }

      workflow_execution.perform_action(:cancel_onboarding, user: hr_user, 
                                       additional_context: additional_data)
      
      # Verify initial context is preserved
      final_context = workflow_execution.context_data
      expect(final_context).to include(initial_context)
      expect(final_context['custom_field']).to eq('custom_value')
      expect(final_context['nested_data']['level1']['level2']).to eq('deep_value')
    end

    it 'tracks comprehensive workflow history' do
      workflow_execution.perform_action(:cancel_onboarding, user: hr_user,
                                       additional_context: { cancellation_reason: 'Position eliminated' })
      
      history = workflow_execution.step_history
      expect(history).not_to be_empty
      
      last_entry = history.last
      expect(last_entry['action']).to eq('cancel_onboarding')
      expect(last_entry['from_step']).to eq('initial_setup')
      expect(last_entry['to_step']).to eq('terminated')
      expect(last_entry['user_id']).to eq(hr_user.id)
    end
  end

  describe 'workflow validation edge cases' do
    it 'handles malformed context gracefully' do
      malformed_context = { 'workflowable' => 'not_a_hash_or_object' }
      expect(EmployeeOnboardingWorkflow.send(:basic_info_complete?, malformed_context)).to be false
    end

    it 'validates start date parsing errors' do
      expect(EmployeeOnboardingWorkflow.send(:start_date_valid?, 'invalid_date')).to be false
      expect(EmployeeOnboardingWorkflow.send(:start_date_valid?, nil)).to be false
    end

    it 'handles missing nested context data' do
      empty_context = {}
      expect(EmployeeOnboardingWorkflow.send(:documentation_complete?, empty_context)).to be false
      expect(EmployeeOnboardingWorkflow.send(:it_setup_complete?, empty_context)).to be false
      expect(EmployeeOnboardingWorkflow.send(:can_resume?, empty_context)).to be false
    end

    describe '.extract_employee_data' do
      it 'extracts data from ActiveRecord object' do
        mock_employee = double('Employee', attributes: { 'name' => 'Test', 'id' => 1 })
        context = { 'workflowable' => mock_employee }
        result = EmployeeOnboardingWorkflow.send(:extract_employee_data, context)
        expect(result).to eq({ 'name' => 'Test', 'id' => 1 })
      end

      it 'extracts data from hash' do
        employee_hash = { 'name' => 'Test', 'id' => 1 }
        context = { 'workflowable' => employee_hash }
        result = EmployeeOnboardingWorkflow.send(:extract_employee_data, context)
        expect(result).to eq(employee_hash)
      end

      it 'handles missing workflowable' do
        context = {}
        result = EmployeeOnboardingWorkflow.send(:extract_employee_data, context)
        expect(result).to be_nil
      end

      it 'handles invalid workflowable type' do
        context = { 'workflowable' => 'invalid_type' }
        result = EmployeeOnboardingWorkflow.send(:extract_employee_data, context)
        expect(result).to be_nil
      end
    end

    describe '.training_modules_ready?' do
      it 'returns true when modules assigned and timeline established' do
        context = {
          'workflowable' => full_time_employee.as_json,
          'training_config' => {
            'modules_assigned' => ['orientation'],
            'timeline_established' => true
          }
        }
        expect(EmployeeOnboardingWorkflow.send(:training_modules_ready?, context)).to be true
      end

      it 'returns false when timeline not established' do
        context = {
          'workflowable' => full_time_employee.as_json,
          'training_config' => {
            'modules_assigned' => ['orientation'],
            'timeline_established' => false
          }
        }
        expect(EmployeeOnboardingWorkflow.send(:training_modules_ready?, context)).to be false
      end

      it 'returns false when no modules assigned' do
        context = {
          'workflowable' => full_time_employee.as_json,
          'training_config' => {
            'timeline_established' => true
          }
        }
        expect(EmployeeOnboardingWorkflow.send(:training_modules_ready?, context)).to be false
      end
    end

    describe '.benefits_finalized?' do
      it 'returns true when all benefits configured' do
        context = {
          'benefits_package' => {
            'health_insurance' => 'selected',
            'retirement_plan' => 'configured',
            'pto_allocation' => 20
          }
        }
        expect(EmployeeOnboardingWorkflow.send(:benefits_finalized?, context)).to be true
      end

      it 'returns false when benefits incomplete' do
        context = {
          'benefits_package' => {
            'health_insurance' => 'pending',
            'retirement_plan' => 'configured',
            'pto_allocation' => 20
          }
        }
        expect(EmployeeOnboardingWorkflow.send(:benefits_finalized?, context)).to be false
      end

      it 'returns false when no benefits context' do
        context = {}
        expect(EmployeeOnboardingWorkflow.send(:benefits_finalized?, context)).to be false
      end
    end
  end
end