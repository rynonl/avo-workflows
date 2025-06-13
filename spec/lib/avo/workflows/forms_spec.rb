# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Avo::Workflows::Forms do
  # Clear registry between tests to avoid shared state
  before do
    Avo::Workflows::Forms::Registry.forms.clear
  end
  # Create a test workflow class for testing
  let(:test_workflow_class) do
    Class.new(Avo::Workflows::Base) do
      def self.name
        'TestWorkflow'
      end
      
      step :draft do
        action :submit, to: :review
      end
      
      step :review do
        action :approve, to: :approved
      end
      
      step :approved
    end
  end
  
  let(:user) { User.create!(name: 'Test User', email: 'test@example.com') }
  let(:workflowable) { User.create!(name: 'Test Target', email: 'target@example.com') }
  # For forms testing, we'll use a simpler mock workflow execution
  let(:workflow_execution) do
    double('WorkflowExecution',
      id: 1,
      workflow_class: 'TestWorkflow',
      workflowable: workflowable,
      current_step: 'draft',
      context_data: { initial: true },
      assigned_to: user
    )
  end

  describe Avo::Workflows::Forms::Base do
    let(:test_form_class) do
      Class.new(described_class) do
        def self.name
          'TestFormClass'
        end
        
        # Reset field_definitions to avoid shared state
        self.field_definitions = []
        
        title "Test Form"
        description "A form for testing"

        field :name, as: :text, required: true
        field :description, as: :textarea, required: false
        field :priority, as: :select, options: ['low', 'medium', 'high'], required: true
        field :urgent, as: :boolean, default: false
        field :due_date, as: :date

        validates :name, length: { minimum: 3 }
      end
    end

    describe '.field' do
      it 'defines field definitions' do
        expect(test_form_class.field_definitions.length).to eq(5)
        
        name_field = test_form_class.field_definitions.find { |f| f[:name] == :name }
        expect(name_field[:type]).to eq(:text)
        expect(name_field[:options][:required]).to be true
      end

      it 'creates attribute accessors' do
        form = test_form_class.new
        expect(form).to respond_to(:name)
        expect(form).to respond_to(:name=)
        expect(form).to respond_to(:priority)
        expect(form).to respond_to(:urgent)
      end
    end

    describe '#initialize' do
      it 'accepts workflow execution and user' do
        form = test_form_class.new(
          workflow_execution: workflow_execution,
          current_user: user,
          action_name: :test_action,
          name: 'Test Name',
          priority: 'high'
        )

        expect(form.workflow_execution).to eq(workflow_execution)
        expect(form.current_user).to eq(user)
        expect(form.action_name).to eq(:test_action)
        expect(form.name).to eq('Test Name')
        expect(form.priority).to eq('high')
      end

      it 'sets default values' do
        form = test_form_class.new
        expect(form.urgent).to be false
      end
    end

    describe '#valid?' do
      it 'validates required fields' do
        form = test_form_class.new(name: '', priority: '')
        expect(form).not_to be_valid
        expect(form.errors[:name]).to include("can't be blank")
        expect(form.errors[:priority]).to include("can't be blank")
      end

      it 'validates custom validations' do
        form = test_form_class.new(name: 'ab', priority: 'high')
        expect(form).not_to be_valid
        expect(form.errors[:name]).to include("is too short (minimum is 3 characters)")
      end

      it 'passes validation with valid data' do
        form = test_form_class.new(
          name: 'Valid Name',
          priority: 'medium',
          urgent: true,
          due_date: Date.tomorrow
        )
        expect(form).to be_valid
      end
    end

    describe '#to_context' do
      it 'converts form data to context hash' do
        form = test_form_class.new(
          name: 'Test Task',
          description: 'A test description',
          priority: 'high',
          urgent: true,
          due_date: Date.tomorrow
        )

        context = form.to_context
        expect(context).to eq({
          name: 'Test Task',
          description: 'A test description', 
          priority: 'high',
          urgent: true,
          due_date: Date.tomorrow
        })
      end
    end

    describe '#render_avo_form' do
      it 'renders form data for Avo' do
        form = test_form_class.new(name: 'Test', priority: 'medium')
        rendered = form.render_avo_form

        expect(rendered[:title]).to eq("Test Form")
        expect(rendered[:description]).to eq("A form for testing")
        expect(rendered[:fields].length).to eq(5)

        name_field = rendered[:fields].find { |f| f[:name] == :name }
        expect(name_field[:type]).to eq(:text)
        expect(name_field[:required]).to be true
        expect(name_field[:value]).to eq('Test')
      end
    end

    describe '.field_type_to_active_model_type' do
      it 'converts field types correctly' do
        expect(test_form_class.field_type_to_active_model_type(:text)).to eq(:string)
        expect(test_form_class.field_type_to_active_model_type(:boolean)).to eq(:boolean)
        expect(test_form_class.field_type_to_active_model_type(:number)).to eq(:integer)
        expect(test_form_class.field_type_to_active_model_type(:date)).to eq(:date)
      end
    end
  end

  describe Avo::Workflows::Forms::Registry do
    let(:workflow_class) do
      Class.new do
        def self.name
          'TestWorkflowClass'
        end
      end
    end
    let(:form_class) { Class.new(Avo::Workflows::Forms::Base) }

    before do
      described_class.forms.clear
    end

    describe '.register' do
      it 'registers form for workflow action' do
        described_class.register(workflow_class, :test_action, form_class)
        
        key = "#{workflow_class.name}#test_action"
        expect(described_class.forms[key]).to eq(form_class)
      end
    end

    describe '.get' do
      it 'retrieves registered form' do
        described_class.register(workflow_class, :test_action, form_class)
        
        result = described_class.get(workflow_class, :test_action)
        expect(result).to eq(form_class)
      end

      it 'returns nil for unregistered form' do
        result = described_class.get(workflow_class, :unknown_action)
        expect(result).to be_nil
      end
    end

    describe '.has_form?' do
      it 'returns true for registered form' do
        described_class.register(workflow_class, :test_action, form_class)
        
        expect(described_class.has_form?(workflow_class, :test_action)).to be true
      end

      it 'returns false for unregistered form' do
        expect(described_class.has_form?(workflow_class, :unknown_action)).to be false
      end
    end
  end

  describe Avo::Workflows::Forms::WorkflowFormMethods do
    let(:workflow_class) do
      Class.new do
        include Avo::Workflows::Forms::WorkflowFormMethods
        
        def self.name
          'TestWorkflow'
        end
      end
    end
    let(:form_class) { Class.new(Avo::Workflows::Forms::Base) }

    describe '.action_form' do
      it 'registers form with registry' do
        workflow_class.action_form(:approve, form_class)
        
        expect(Avo::Workflows::Forms::Registry.get(workflow_class, :approve)).to eq(form_class)
      end
    end

    describe '.action_form_for' do
      it 'creates and registers inline form' do
        workflow_class.action_form_for(:reject) do
          field :reason, as: :textarea, required: true
        end

        form_class = workflow_class.form_for_action(:reject)
        expect(form_class).to be_present
        expect(form_class.field_definitions.length).to eq(1)
        expect(form_class.field_definitions.first[:name]).to eq(:reason)
      end
    end

    describe '.form_for_action' do
      it 'retrieves form for action' do
        workflow_class.action_form(:approve, form_class)
        
        result = workflow_class.form_for_action(:approve)
        expect(result).to eq(form_class)
      end
    end

    describe '.action_has_form?' do
      it 'checks if action has form' do
        workflow_class.action_form(:approve, form_class)
        
        expect(workflow_class.action_has_form?(:approve)).to be true
        expect(workflow_class.action_has_form?(:reject)).to be false
      end
    end
  end

  describe Avo::Workflows::Forms::CommonFields do
    describe '.approval_fields' do
      it 'returns standard approval fields' do
        fields = described_class.approval_fields
        
        expect(fields).to be_an(Array)
        expect(fields.size).to be >= 2
        
        comments_field = fields.find { |f| f[:name] == :approval_comments }
        expect(comments_field[:as]).to eq(:textarea)
        expect(comments_field[:required]).to be false
      end
    end

    describe '.assignment_fields' do
      it 'returns standard assignment fields' do
        fields = described_class.assignment_fields
        
        expect(fields).to be_an(Array)
        expect(fields.size).to be >= 3
        
        user_field = fields.find { |f| f[:name] == :assigned_user_id }
        expect(user_field[:as]).to eq(:select)
        expect(user_field[:required]).to be true
      end
    end

    describe '.rejection_fields' do
      it 'returns standard rejection fields' do
        fields = described_class.rejection_fields
        
        expect(fields).to be_an(Array)
        expect(fields.size).to be >= 3
        
        reason_field = fields.find { |f| f[:name] == :rejection_reason }
        expect(reason_field[:as]).to eq(:textarea)
        expect(reason_field[:required]).to be true
      end
    end
  end

  describe 'Integration with workflow execution' do
    let(:approval_form_class) do
      Class.new(Avo::Workflows::Forms::Base) do
        def self.name
          'ApprovalFormClass'
        end
        
        # Reset field_definitions to avoid shared state
        self.field_definitions = []
        
        field :comments, as: :textarea, required: true
        field :notify_team, as: :boolean, default: true
        
        validates :comments, length: { minimum: 10 }
      end
    end

    it 'validates form data before workflow action' do
      form = approval_form_class.new(
        workflow_execution: workflow_execution,
        current_user: user,
        action_name: :approve,
        comments: 'Too short',
        notify_team: true
      )

      expect(form).not_to be_valid
      expect(form.errors[:comments]).to include("is too short (minimum is 10 characters)")
    end

    it 'provides valid form data as context' do
      form = approval_form_class.new(
        workflow_execution: workflow_execution,
        current_user: user,
        action_name: :approve,
        comments: 'This looks good to me, approved!',
        notify_team: true
      )

      expect(form).to be_valid
      
      context = form.to_context
      expect(context).to eq({
        comments: 'This looks good to me, approved!',
        notify_team: true
      })
    end
  end

  describe 'Complex form with conditional validation' do
    let(:complex_form_class) do
      Class.new(Avo::Workflows::Forms::Base) do
        def self.name
          'ComplexFormClass'
        end
        
        # Reset field_definitions to avoid shared state
        self.field_definitions = []
        
        field :approval_type, as: :select, 
              options: ['standard', 'expedited', 'emergency'], 
              required: true
        field :justification, as: :textarea
        field :manager_approval, as: :boolean
        field :emergency_contact, as: :text

        validate :justification_required_for_expedited
        validate :manager_approval_required_for_emergency
        validate :emergency_contact_required_for_emergency

        private

        def justification_required_for_expedited
          if approval_type == 'expedited' && justification.blank?
            errors.add(:justification, 'is required for expedited approval')
          end
        end

        def manager_approval_required_for_emergency
          if approval_type == 'emergency' && !manager_approval
            errors.add(:manager_approval, 'is required for emergency approval')
          end
        end

        def emergency_contact_required_for_emergency
          if approval_type == 'emergency' && emergency_contact.blank?
            errors.add(:emergency_contact, 'is required for emergency approval')
          end
        end
      end
    end

    it 'validates standard approval' do
      form = complex_form_class.new(approval_type: 'standard')
      expect(form).to be_valid
    end

    it 'validates expedited approval requirements' do
      form = complex_form_class.new(approval_type: 'expedited')
      expect(form).not_to be_valid
      expect(form.errors[:justification]).to include('is required for expedited approval')

      form.justification = 'Urgent customer request'
      expect(form).to be_valid
    end

    it 'validates emergency approval requirements' do
      form = complex_form_class.new(approval_type: 'emergency')
      expect(form).not_to be_valid
      expect(form.errors[:manager_approval]).to include('is required for emergency approval')
      expect(form.errors[:emergency_contact]).to include('is required for emergency approval')

      form.manager_approval = true
      form.emergency_contact = 'john.doe@company.com'
      expect(form).to be_valid
    end
  end
end