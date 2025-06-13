# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Employee, type: :model do
  # Test data setup
  let(:hr_user) { User.create!(name: 'HR Manager', email: 'hr@company.com') }
  let(:manager) { User.create!(name: 'Engineering Manager', email: 'manager@company.com') }
  let(:mentor) { User.create!(name: 'Senior Engineer', email: 'mentor@company.com') }
  let(:it_user) { User.create!(name: 'IT Admin', email: 'it@company.com') }
  let(:board_member) { User.create!(name: 'Board Chair', email: 'board@company.com') }

  let(:valid_attributes) do
    {
      name: 'John Doe',
      email: 'john.doe@company.com',
      employee_type: 'full_time',
      department: 'Engineering',
      salary_level: 'senior',
      start_date: Date.current + 1.week,
      manager: manager,
      hr_representative: hr_user
    }
  end

  describe 'associations' do
    it 'belongs to manager' do
      employee = Employee.new(valid_attributes)
      expect(employee.manager).to eq(manager)
    end

    it 'belongs to mentor (optional)' do
      employee = Employee.new(valid_attributes)
      expect(employee.mentor).to be_nil
      employee.mentor = mentor
      expect(employee.mentor).to eq(mentor)
    end

    it 'belongs to hr_representative' do
      employee = Employee.new(valid_attributes)
      expect(employee.hr_representative).to eq(hr_user)
    end

    it 'has one workflow execution' do
      employee = Employee.create!(valid_attributes)
      expect(employee.workflow_execution).to be_nil
      employee.start_onboarding!
      expect(employee.reload.workflow_execution).to be_present
    end
  end

  describe 'validations' do
    it 'validates presence of required fields' do
      employee = Employee.new
      expect(employee).not_to be_valid
      
      required_fields = %w[name email employee_type department salary_level start_date]
      required_fields.each do |field|
        expect(employee.errors[field]).to include("can't be blank")
      end
    end

    it 'validates email uniqueness and format' do
      Employee.create!(valid_attributes)
      duplicate = Employee.new(valid_attributes)
      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:email]).to include('has already been taken')

      invalid_email = Employee.new(valid_attributes.merge(email: 'invalid_email'))
      expect(invalid_email).not_to be_valid
      expect(invalid_email.errors[:email]).to include('is invalid')
    end

    it 'validates employee_type inclusion' do
      invalid_type = Employee.new(valid_attributes.merge(employee_type: 'invalid_type'))
      expect(invalid_type).not_to be_valid
      expect(invalid_type.errors[:employee_type]).to include('is not included in the list')
    end

    it 'validates department inclusion' do
      invalid_dept = Employee.new(valid_attributes.merge(department: 'InvalidDept'))
      expect(invalid_dept).not_to be_valid
      expect(invalid_dept.errors[:department]).to include('is not included in the list')
    end

    it 'validates security_clearance inclusion' do
      valid_clearances = %w[none standard confidential secret top_secret]
      valid_clearances.each do |clearance|
        employee = Employee.new(valid_attributes.merge(security_clearance: clearance))
        expect(employee).to be_valid
      end

      invalid_clearance = Employee.new(valid_attributes.merge(security_clearance: 'invalid'))
      expect(invalid_clearance).not_to be_valid
    end

    describe 'custom validations' do
      it 'requires start_date in future' do
        past_date = Employee.new(valid_attributes.merge(start_date: Date.current - 1.day))
        expect(past_date).not_to be_valid
        expect(past_date.errors[:start_date]).to include('must be at least 3 days in the future')

        near_future = Employee.new(valid_attributes.merge(start_date: Date.current + 1.day))
        expect(near_future).not_to be_valid
      end

      it 'requires manager for non-executives' do
        no_manager = Employee.new(valid_attributes.merge(manager: nil))
        expect(no_manager).not_to be_valid
        expect(no_manager.errors[:manager]).to include('is required for non-executive employees')

        # Executives can have no manager initially
        executive = Employee.new(valid_attributes.merge(
          employee_type: 'executive', 
          salary_level: 'executive',
          manager: nil
        ))
        expect(executive).to be_valid
      end

      it 'validates executive salary levels' do
        exec_low_salary = Employee.new(valid_attributes.merge(
          employee_type: 'executive',
          salary_level: 'junior',
          manager: nil
        ))
        expect(exec_low_salary).not_to be_valid
        expect(exec_low_salary.errors[:salary_level]).to include('must be executive level')
      end

      it 'validates intern start date within 6 months' do
        far_future_intern = Employee.new(valid_attributes.merge(
          employee_type: 'intern',
          start_date: Date.current + 8.months
        ))
        expect(far_future_intern).not_to be_valid
        expect(far_future_intern.errors[:start_date]).to include('for interns should be within 6 months')
      end
    end
  end

  describe 'scopes' do
    let!(:pending_employee) { Employee.create!(valid_attributes) }
    let!(:complete_employee) { Employee.create!(valid_attributes.merge(email: 'complete@company.com')) }
    let!(:terminated_employee) { Employee.create!(valid_attributes.merge(email: 'terminated@company.com')) }

    before do
      # Set up different workflow states
      pending_employee.start_onboarding!
      
      complete_employee.start_onboarding!
      complete_employee.workflow_execution.update!(current_step: 'completed')
      
      terminated_employee.start_onboarding!
      terminated_employee.workflow_execution.update!(current_step: 'terminated')
    end

    describe 'workflow state scopes' do
      it 'pending_onboarding returns employees not completed or terminated' do
        expect(Employee.pending_onboarding).to include(pending_employee)
        expect(Employee.pending_onboarding).not_to include(complete_employee, terminated_employee)
      end

      it 'onboarding_complete returns completed employees' do
        expect(Employee.onboarding_complete).to include(complete_employee)
        expect(Employee.onboarding_complete).not_to include(pending_employee, terminated_employee)
      end

      it 'onboarding_terminated returns terminated employees' do
        expect(Employee.onboarding_terminated).to include(terminated_employee)
        expect(Employee.onboarding_terminated).not_to include(pending_employee, complete_employee)
      end
    end

    describe 'employee type scopes' do
      let!(:intern) { Employee.create!(valid_attributes.merge(employee_type: 'intern', email: 'intern@company.com')) }
      let!(:contractor) { Employee.create!(valid_attributes.merge(employee_type: 'contractor', email: 'contractor@company.com')) }

      it 'filters by employee type correctly' do
        expect(Employee.full_time_employees).to include(pending_employee, complete_employee, terminated_employee)
        expect(Employee.interns).to include(intern)
        expect(Employee.contractors).to include(contractor)
      end
    end
  end

  describe 'employee type methods' do
    it 'correctly identifies employee types' do
      full_time = Employee.new(employee_type: 'full_time')
      expect(full_time.full_time?).to be true
      expect(full_time.contractor?).to be false

      contractor = Employee.new(employee_type: 'contractor')
      expect(contractor.contractor?).to be true
      expect(contractor.full_time?).to be false

      intern = Employee.new(employee_type: 'intern')
      expect(intern.intern?).to be true
      expect(intern.executive?).to be false

      executive = Employee.new(employee_type: 'executive')
      expect(executive.executive?).to be true
      expect(executive.intern?).to be false
    end
  end

  describe 'security clearance methods' do
    it 'correctly identifies security clearance requirements' do
      no_clearance = Employee.new(security_clearance: 'none')
      expect(no_clearance.requires_security_clearance?).to be false

      standard_clearance = Employee.new(security_clearance: 'standard')
      expect(standard_clearance.requires_security_clearance?).to be true
      expect(standard_clearance.high_security_clearance?).to be false

      high_clearance = Employee.new(security_clearance: 'secret')
      expect(high_clearance.requires_security_clearance?).to be true
      expect(high_clearance.high_security_clearance?).to be true
    end
  end

  describe 'workflow status methods' do
    let(:employee) { Employee.create!(valid_attributes) }

    context 'without workflow' do
      it 'returns appropriate status messages' do
        expect(employee.onboarding_status).to eq('Not started')
        expect(employee.onboarding_complete?).to be false
        expect(employee.onboarding_in_progress?).to be false
        expect(employee.ready_to_start?).to be false
      end
    end

    context 'with workflow in progress' do
      before { employee.start_onboarding! }

      it 'returns human-readable status' do
        expect(employee.onboarding_status).to eq('Setting up employee record')
        expect(employee.onboarding_complete?).to be false
        expect(employee.onboarding_in_progress?).to be true
      end

      it 'calculates progress percentage' do
        expect(employee.onboarding_progress_percentage).to be >= 0
        expect(employee.onboarding_progress_percentage).to be <= 100
      end
    end

    context 'with completed workflow' do
      before do
        employee.start_onboarding!
        employee.workflow_execution.update!(current_step: 'completed')
      end

      it 'returns completed status' do
        expect(employee.onboarding_status).to eq('Onboarding complete')
        expect(employee.onboarding_complete?).to be true
        expect(employee.onboarding_in_progress?).to be false
        expect(employee.ready_to_start?).to be true
        expect(employee.onboarding_progress_percentage).to eq(100)
      end
    end
  end

  describe 'workflow management' do
    let(:employee) { Employee.create!(valid_attributes) }

    describe '#start_onboarding!' do
      it 'creates workflow execution with rich context' do
        execution = employee.start_onboarding!
        
        expect(execution).to be_a(Avo::Workflows::WorkflowExecution)
        expect(execution.assigned_to).to eq(hr_user)
        expect(execution.workflowable).to eq(employee)
        
        context = execution.context_data
        expect(context['employee_name']).to eq('John Doe')
        expect(context['employee_type']).to eq('full_time')
        expect(context['department']).to eq('Engineering')
        expect(context['requires_mentor']).to be false
        expect(context['requires_board_approval']).to be false
      end

      it 'allows custom assignment' do
        execution = employee.start_onboarding!(assigned_to: manager)
        expect(execution.assigned_to).to eq(manager)
      end

      it 'returns existing workflow if already present' do
        first_execution = employee.start_onboarding!
        second_execution = employee.start_onboarding!
        expect(second_execution).to eq(first_execution)
      end

      it 'includes additional context when provided' do
        additional = { custom_field: 'custom_value' }
        execution = employee.start_onboarding!(additional_context: additional)
        expect(execution.context_data['custom_field']).to eq('custom_value')
      end
    end

    describe 'workflow action methods' do
      before { employee.start_onboarding! }

      describe '#begin_documentation_review!' do
        it 'transitions to documentation review' do
          result = employee.begin_documentation_review!(manager: manager, notes: 'Ready for review')
          expect(result).to be true
          expect(employee.workflow_execution.current_step).to eq('documentation_review')
        end

        it 'updates manager assignment' do
          new_manager = User.create!(name: 'New Manager', email: 'new@company.com')
          employee.begin_documentation_review!(manager: new_manager)
          expect(employee.reload.manager).to eq(new_manager)
        end
      end

      describe '#approve_documentation!' do
        before do
          employee.workflow_execution.update!(current_step: 'documentation_review')
          employee.workflow_execution.update_context!({
            'documentation' => {
              'employment_contract' => 'approved',
              'background_check' => 'approved',
              'references' => 'approved'
            },
            'benefits_package' => {
              'health_insurance' => 'selected',
              'retirement_plan' => 'configured',
              'pto_allocation' => 25
            }
          })
        end

        it 'transitions to IT provisioning' do
          result = employee.approve_documentation!(manager: manager, documentation_notes: 'All good')
          expect(result).to be true
          expect(employee.workflow_execution.current_step).to eq('it_provisioning')
        end

        it 'includes documentation notes in context' do
          employee.approve_documentation!(manager: manager, documentation_notes: 'Excellent candidate')
          context = employee.workflow_execution.context_data
          expect(context['manager_approval_notes']).to eq('Excellent candidate')
        end
      end

      describe '#assign_training!' do
        before do
          employee.workflow_execution.update!(current_step: 'training_assignment')
          employee.workflow_execution.update_context!({
            'training_config' => {
              'modules_assigned' => ['orientation'],
              'timeline_established' => true
            }
          })
        end

        it 'assigns standard training for full-time employees' do
          result = employee.assign_training!(hr_user: hr_user)
          expect(result).to be true
          expect(employee.workflow_execution.current_step).to eq('training_in_progress')
        end

        it 'includes custom modules in training config' do
          custom_modules = ['advanced_security', 'leadership_prep']
          employee.assign_training!(hr_user: hr_user, custom_modules: custom_modules)
          
          context = employee.workflow_execution.context_data
          training_config = context['training_config']
          expect(training_config['modules_assigned']).to include(*custom_modules)
        end
      end
    end

    describe 'intern-specific workflow methods' do
      let(:intern) do
        Employee.create!(valid_attributes.merge(
          employee_type: 'intern',
          email: 'intern@company.com'
        ))
      end

      before { intern.start_onboarding! }

      describe '#assign_mentor!' do
        before do
          intern.workflow_execution.update!(current_step: 'mentor_assignment')
        end

        it 'assigns mentor and transitions workflow' do
          goals = ['Learn Ruby', 'Complete project', 'Present findings']
          result = intern.assign_mentor!(
            mentor_user: mentor,
            hr_user: hr_user,
            mentorship_goals: goals
          )
          
          expect(result).to be true
          expect(intern.reload.mentor).to eq(mentor)
          expect(intern.workflow_execution.current_step).to eq('training_in_progress')
          
          context = intern.workflow_execution.context_data
          expect(context['mentor_assignment']['mentorship_goals']).to eq(goals)
        end

        it 'fails for non-intern employees' do
          result = employee.assign_mentor!(mentor_user: mentor, hr_user: hr_user)
          expect(result).to be false
        end
      end
    end

    describe 'executive-specific workflow methods' do
      let(:executive) do
        Employee.create!(valid_attributes.merge(
          employee_type: 'executive',
          salary_level: 'c_level',
          email: 'exec@company.com',
          manager: nil
        ))
      end

      before { executive.start_onboarding! }

      describe '#grant_board_approval!' do
        before do
          executive.workflow_execution.update!(current_step: 'executive_approval')
        end

        it 'grants board approval and transitions workflow' do
          result = executive.grant_board_approval!(
            board_member: board_member,
            meeting_minutes: 'Approved unanimously in Board Meeting #47'
          )
          
          expect(result).to be true
          expect(executive.workflow_execution.current_step).to eq('training_in_progress')
          
          context = executive.workflow_execution.context_data
          approval = context['board_approval']
          expect(approval['status']).to eq('approved')
          expect(approval['board_meeting_minutes']).to include('Board Meeting #47')
        end

        it 'fails for non-executive employees' do
          result = employee.grant_board_approval!(board_member: board_member, meeting_minutes: 'Test')
          expect(result).to be false
        end
      end
    end

    describe '#approve_final_onboarding!' do
      before do
        employee.start_onboarding!
        employee.workflow_execution.update!(current_step: 'final_review')
        employee.workflow_execution.update_context!({
          'final_review' => {
            'workspace_ready' => true,
            'first_day_planned' => true,
            'goals_established' => true,
            'feedback_collected' => true
          }
        })
      end

      it 'completes onboarding workflow' do
        result = employee.approve_final_onboarding!(manager: manager)
        expect(result).to be true
        expect(employee.workflow_execution.current_step).to eq('completed')
        expect(employee.workflow_execution.status).to eq('completed')
      end

      it 'includes final review details in context' do
        employee.approve_final_onboarding!(
          manager: manager,
          workspace_ready: true,
          goals_established: true
        )
        
        context = employee.workflow_execution.context_data
        final_review = context['final_review']
        expect(final_review['approved_by_manager']).to eq(manager.id)
        expect(final_review['workspace_ready']).to be true
      end
    end
  end

  describe 'utility methods' do
    let(:employee) { Employee.create!(valid_attributes) }

    it 'returns available workflow actions' do
      expect(employee.available_onboarding_actions).to eq([])
      
      employee.start_onboarding!
      actions = employee.available_onboarding_actions
      expect(actions).to include(:begin_documentation_review, :cancel_onboarding)
    end

    it 'returns onboarding history' do
      expect(employee.onboarding_history).to eq([])
      
      employee.start_onboarding!
      employee.begin_documentation_review!(manager: manager)
      
      history = employee.onboarding_history
      expect(history).not_to be_empty
      expect(history.last['action']).to eq('begin_documentation_review')
    end

    it 'calculates progress percentage correctly' do
      expect(employee.onboarding_progress_percentage).to eq(0)
      
      employee.start_onboarding!
      initial_progress = employee.onboarding_progress_percentage
      
      employee.workflow_execution.update!(current_step: 'final_review')
      final_progress = employee.onboarding_progress_percentage
      
      expect(final_progress).to be > initial_progress
      
      employee.workflow_execution.update!(current_step: 'completed')
      expect(employee.onboarding_progress_percentage).to eq(100)
    end
  end

  describe 'complex business logic' do
    it 'builds appropriate context for different employee types' do
      # Full-time employee
      full_time = Employee.create!(valid_attributes)
      execution = full_time.start_onboarding!
      context = execution.context_data
      
      expect(context['requires_mentor']).to be false
      expect(context['requires_board_approval']).to be false
      
      # Intern
      intern = Employee.create!(valid_attributes.merge(
        employee_type: 'intern',
        email: 'intern@company.com'
      ))
      intern_execution = intern.start_onboarding!
      intern_context = intern_execution.context_data
      
      expect(intern_context['requires_mentor']).to be true
      expect(intern_context['requires_board_approval']).to be false
      
      # Executive
      executive = Employee.create!(valid_attributes.merge(
        employee_type: 'executive',
        salary_level: 'c_level',
        email: 'exec@company.com',
        manager: nil
      ))
      exec_execution = executive.start_onboarding!
      exec_context = exec_execution.context_data
      
      expect(exec_context['requires_mentor']).to be false
      expect(exec_context['requires_board_approval']).to be true
    end

    it 'handles contractor ready-to-start logic' do
      contractor = Employee.create!(valid_attributes.merge(
        employee_type: 'contractor',
        email: 'contractor@company.com'
      ))
      
      # Not ready without IT access
      expect(contractor.ready_to_start?).to be false
      
      # Ready with IT access (even without full onboarding)
      contractor.start_onboarding!
      contractor.workflow_execution.update_context!({
        'it_provisioning' => { 'email_account' => 'completed' }
      })
      expect(contractor.ready_to_start?).to be true
    end

    describe 'context building helper methods' do
      let(:employee) { Employee.create!(valid_attributes) }

      it 'calculates estimated completion date correctly' do
        # Full-time employee should take 14 days
        expect(employee.send(:calculate_estimated_completion_date)).to eq(employee.start_date + 14.days)
        
        # Contractor should take 7 days
        contractor = Employee.create!(valid_attributes.merge(
          employee_type: 'contractor',
          email: 'contractor@test.com'
        ))
        expect(contractor.send(:calculate_estimated_completion_date)).to eq(contractor.start_date + 7.days)
        
        # Intern should take 21 days
        intern = Employee.create!(valid_attributes.merge(
          employee_type: 'intern',
          email: 'intern@test.com'
        ))
        expect(intern.send(:calculate_estimated_completion_date)).to eq(intern.start_date + 21.days)
      end

      it 'calculates PTO allocation based on salary level' do
        expect(employee.send(:calculate_pto_allocation)).to eq(25) # senior level
        
        junior_employee = Employee.create!(valid_attributes.merge(
          salary_level: 'junior',
          email: 'junior@test.com'
        ))
        expect(junior_employee.send(:calculate_pto_allocation)).to eq(15)
        
        executive = Employee.create!(valid_attributes.merge(
          employee_type: 'executive',
          salary_level: 'c_level',
          email: 'exec@test.com',
          manager: nil
        ))
        expect(executive.send(:calculate_pto_allocation)).to eq(30)
      end

      it 'determines additional benefits correctly' do
        benefits = employee.send(:determine_additional_benefits)
        expect(benefits).to include('stock_options') # senior level
        expect(benefits).to include('flexible_schedule') # engineering dept
        expect(benefits).to include('professional_development') # not contractor
        
        contractor = Employee.create!(valid_attributes.merge(
          employee_type: 'contractor',
          salary_level: 'junior',
          email: 'contractor@test.com'
        ))
        contractor_benefits = contractor.send(:determine_additional_benefits)
        expect(contractor_benefits).not_to include('stock_options') # junior level
        expect(contractor_benefits).not_to include('professional_development') # contractor
      end

      it 'assigns training modules by employee type' do
        modules = employee.send(:training_modules_for_type)
        expect(modules).to include('benefits_overview', 'career_development')
        
        contractor = Employee.create!(valid_attributes.merge(
          employee_type: 'contractor',
          email: 'contractor@test.com'
        ))
        contractor_modules = contractor.send(:training_modules_for_type)
        expect(contractor_modules).to include('contractor_guidelines', 'project_specific')
        
        intern = Employee.create!(valid_attributes.merge(
          employee_type: 'intern',
          email: 'intern@test.com'
        ))
        intern_modules = intern.send(:training_modules_for_type)
        expect(intern_modules).to include('mentorship_program', 'academic_credit')
      end

      it 'assigns training modules by department' do
        modules = employee.send(:training_modules_for_department) # Engineering
        expect(modules).to include('technical_stack', 'code_review', 'security_practices')
        
        sales_employee = Employee.create!(valid_attributes.merge(
          department: 'Sales',
          email: 'sales@test.com'
        ))
        sales_modules = sales_employee.send(:training_modules_for_department)
        expect(sales_modules).to include('crm_training', 'sales_methodology')
      end

      it 'calculates training duration by employee type' do
        duration = employee.send(:calculate_training_duration)
        expect(duration).to eq('24 hours') # full-time default
        
        contractor = Employee.create!(valid_attributes.merge(
          employee_type: 'contractor',
          email: 'contractor@test.com'
        ))
        expect(contractor.send(:calculate_training_duration)).to eq('8 hours')
        
        intern = Employee.create!(valid_attributes.merge(
          employee_type: 'intern',
          email: 'intern@test.com'
        ))
        expect(intern.send(:calculate_training_duration)).to eq('40 hours')
      end
    end
  end
end