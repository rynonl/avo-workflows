# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Avo::Workflows::Base do
  # Test workflow class
  let(:test_workflow_class) do
    Class.new(described_class) do
      step :draft do
        action :submit, to: :review
        action :save, to: :draft
      end

      step :review do
        action :approve, to: :approved
        action :reject, to: :rejected
        action :request_changes, to: :draft
      end

      step :approved do
        # Final step
      end

      step :rejected do
        action :resubmit, to: :draft
      end
    end
  end

  describe '.step' do
    it 'defines a workflow step' do
      expect(test_workflow_class.step_names).to include(:draft, :review, :approved, :rejected)
    end

    it 'returns a StepDefinition object' do
      step_def = test_workflow_class.find_step(:draft)
      expect(step_def).to be_a(Avo::Workflows::Base::StepDefinition)
      expect(step_def.name).to eq(:draft)
    end
  end

  describe '.step_names' do
    it 'returns all defined step names' do
      expect(test_workflow_class.step_names).to eq([:draft, :review, :approved, :rejected])
    end
  end

  describe '.find_step' do
    it 'finds step by name' do
      step = test_workflow_class.find_step(:draft)
      expect(step.name).to eq(:draft)
    end

    it 'returns nil for non-existent step' do
      expect(test_workflow_class.find_step(:nonexistent)).to be_nil
    end
  end

  describe '.final_steps' do
    it 'identifies steps with no actions as final' do
      expect(test_workflow_class.final_steps).to eq([:approved])
    end
  end

  describe '.initial_step' do
    it 'returns the first defined step' do
      expect(test_workflow_class.initial_step).to eq(:draft)
    end
  end

  describe '#available_actions_for_step' do
    subject { test_workflow_class.new }

    it 'returns available actions for a step' do
      actions = subject.available_actions_for_step(:draft)
      expect(actions).to include(:submit, :save)
    end

    it 'returns empty array for non-existent step' do
      actions = subject.available_actions_for_step(:nonexistent)
      expect(actions).to eq([])
    end
  end

  describe '#can_transition?' do
    subject { test_workflow_class.new }

    it 'returns true for valid transitions' do
      expect(subject.can_transition?(:draft, :submit, :review)).to be true
    end

    it 'returns false for invalid transitions' do
      expect(subject.can_transition?(:draft, :submit, :approved)).to be false
    end
  end

  describe '#final_step?' do
    subject { test_workflow_class.new }

    it 'returns true for final steps' do
      expect(subject.final_step?(:approved)).to be true
    end

    it 'returns false for non-final steps' do
      expect(subject.final_step?(:draft)).to be false
    end
  end

  describe '.validate_definition' do
    it 'returns no errors for valid workflow' do
      errors = test_workflow_class.validate_definition
      expect(errors).to be_empty
    end

    it 'returns error for workflow with no steps' do
      empty_workflow = Class.new(described_class)
      errors = empty_workflow.validate_definition
      expect(errors).to include('Workflow must define at least one step')
    end

    it 'returns error for invalid action target' do
      invalid_workflow = Class.new(described_class) do
        step :start do
          action :go, to: :nonexistent
        end
      end
      errors = invalid_workflow.validate_definition
      expect(errors).to include("Step 'start' has action targeting undefined step 'nonexistent'")
    end

    it 'returns error for unreachable steps' do
      unreachable_workflow = Class.new(described_class) do
        step :start do
          action :next, to: :middle
        end

        step :middle do
          # final step
        end

        step :unreachable do
          # This step is unreachable
        end
      end
      errors = unreachable_workflow.validate_definition
      expect(errors).to include("Step 'unreachable' is unreachable from initial step")
    end
  end

  describe '.create_execution_for' do
    let(:workflowable) { double('workflowable') }
    let(:execution_model) { double('execution_model') }

    before do
      allow(Avo::Workflows.configuration).to receive(:workflow_execution_model).and_return(execution_model)
      allow(test_workflow_class).to receive(:name).and_return('TestWorkflow')
    end

    it 'creates execution with correct parameters' do
      expect(execution_model).to receive(:create!).with({
        workflow_class: 'TestWorkflow',
        workflowable: workflowable,
        current_step: 'draft',
        assigned_to: nil,
        context_data: {}
      })

      test_workflow_class.create_execution_for(workflowable)
    end

    it 'includes assigned_to and initial_context when provided' do
      user = double('user')
      context = { initial: true }

      expect(execution_model).to receive(:create!).with({
        workflow_class: 'TestWorkflow',
        workflowable: workflowable,
        current_step: 'draft',
        assigned_to: user,
        context_data: context
      })

      test_workflow_class.create_execution_for(workflowable, assigned_to: user, initial_context: context)
    end

    it 'raises error when workflow has no initial step' do
      empty_workflow = Class.new(described_class)
      expect {
        empty_workflow.create_execution_for(workflowable)
      }.to raise_error(Avo::Workflows::Error, /no initial step/)
    end
  end

  describe '.inherited' do
    it 'sets up workflow_steps hash for subclass' do
      subclass = Class.new(described_class)
      expect(subclass.workflow_steps).to eq({})
    end
  end

  describe '.step with validation' do
    it 'raises error for duplicate step names' do
      workflow_class = Class.new(described_class)
      workflow_class.step(:duplicate)
      
      expect {
        workflow_class.step(:duplicate)
      }.to raise_error(Avo::Workflows::Error, /already defined/)
    end
  end

  describe 'StepDefinition' do
    let(:step_def) { Avo::Workflows::Base::StepDefinition.new(:test_step) }

    describe '#describe' do
      it 'sets description' do
        step_def.describe('Test description')
        expect(step_def.description).to eq('Test description')
      end
    end

    describe '#requirement' do
      it 'adds requirements' do
        step_def.requirement('Must have valid data')
        step_def.requirement('User must be admin')
        expect(step_def.requirements).to eq(['Must have valid data', 'User must be admin'])
      end
    end

    describe '#action' do
      it 'defines an action with all parameters' do
        condition = proc { |context| context[:valid] }
        step_def.action(:proceed, to: :next_step, condition: condition, 
                       description: 'Move forward', confirmation_required: true)
        
        action_config = step_def.actions[:proceed]
        expect(action_config[:to]).to eq(:next_step)
        expect(action_config[:condition]).to eq(condition)
        expect(action_config[:description]).to eq('Move forward')
        expect(action_config[:confirmation_required]).to be true
      end

      it 'raises error for duplicate action names' do
        step_def.action(:duplicate, to: :next)
        
        expect {
          step_def.action(:duplicate, to: :other)
        }.to raise_error(Avo::Workflows::Error, /already defined/)
      end
    end

    describe '#condition' do
      it 'stores conditions for the step' do
        condition = proc { true }
        step_def.condition(&condition)
        expect(step_def.conditions).to include(condition)
      end
    end

    describe '#satisfies_conditions?' do
      it 'returns true when all conditions pass' do
        step_def.condition { |context| context[:valid] }
        step_def.condition { |context| context[:ready] }
        
        expect(step_def.satisfies_conditions?(valid: true, ready: true)).to be true
      end

      it 'returns false when any condition fails' do
        step_def.condition { |context| context[:valid] }
        step_def.condition { |context| context[:ready] }
        
        expect(step_def.satisfies_conditions?(valid: true, ready: false)).to be false
      end

      it 'returns true when no conditions are defined' do
        expect(step_def.satisfies_conditions?({})).to be true
      end
    end

    describe '#confirmation_required?' do
      it 'returns true for actions requiring confirmation' do
        step_def.action(:risky, to: :next, confirmation_required: true)
        expect(step_def.confirmation_required?(:risky)).to be true
      end

      it 'returns false for actions not requiring confirmation' do
        step_def.action(:safe, to: :next)
        expect(step_def.confirmation_required?(:safe)).to be false
      end

      it 'returns false for non-existent actions' do
        expect(step_def.confirmation_required?(:nonexistent)).to be false
      end
    end
  end

  describe 'workflow with descriptions and requirements' do
    let(:documented_workflow_class) do
      Class.new(described_class) do
        step :draft do
          describe 'Document is being drafted'
          requirement 'Author must be assigned'
          requirement 'Template must be selected'
          action :submit_for_review, to: :review, description: 'Send to reviewer'
        end

        step :review do
          describe 'Document under review'
          action :approve, to: :approved, confirmation_required: true
          action :reject, to: :rejected
        end

        step :approved do
          describe 'Document approved and published'
        end

        step :rejected do
          describe 'Document was rejected'
          action :revise, to: :draft
        end
      end
    end

    it 'stores step descriptions' do
      draft_step = documented_workflow_class.find_step(:draft)
      expect(draft_step.description).to eq('Document is being drafted')
    end

    it 'stores step requirements' do
      draft_step = documented_workflow_class.find_step(:draft)
      expect(draft_step.requirements).to include('Author must be assigned', 'Template must be selected')
    end

    it 'stores action descriptions' do
      draft_step = documented_workflow_class.find_step(:draft)
      action_config = draft_step.actions[:submit_for_review]
      expect(action_config[:description]).to eq('Send to reviewer')
    end

    it 'handles confirmation requirements' do
      review_step = documented_workflow_class.find_step(:review)
      expect(review_step.confirmation_required?(:approve)).to be true
      expect(review_step.confirmation_required?(:reject)).to be false
    end
  end

  describe 'PanelBuilder' do
    let(:panel_builder) { Avo::Workflows::Base::PanelBuilder.new }

    describe '#field' do
      it 'adds field definitions' do
        panel_builder.field :name, as: :text, required: true
        panel_builder.field :priority, as: :select, options: ['low', 'high']
        
        expect(panel_builder.fields.length).to eq(2)
        expect(panel_builder.fields.first).to eq({
          name: :name,
          type: :text,
          options: { required: true }
        })
        expect(panel_builder.fields.second).to eq({
          name: :priority,
          type: :select,
          options: { options: ['low', 'high'] }
        })
      end

      it 'converts field names to symbols' do
        panel_builder.field 'email', as: :text
        expect(panel_builder.fields.first[:name]).to eq(:email)
      end

      it 'converts field types to symbols' do
        panel_builder.field :comments, as: 'textarea'
        expect(panel_builder.fields.first[:type]).to eq(:textarea)
      end
    end
  end

  describe 'StepDefinition with panels and on_submit' do
    let(:step_def) { Avo::Workflows::Base::StepDefinition.new(:test_step) }

    describe '#panel' do
      it 'defines panel fields using block' do
        step_def.panel do
          field :comments, as: :textarea, required: true
          field :priority, as: :select, options: ['low', 'medium', 'high']
          field :notify, as: :boolean, default: true
        end

        expect(step_def.panel_fields.length).to eq(3)
        expect(step_def.panel_fields[0]).to eq({
          name: :comments,
          type: :textarea,
          options: { required: true }
        })
        expect(step_def.panel_fields[1]).to eq({
          name: :priority,
          type: :select,
          options: { options: ['low', 'medium', 'high'] }
        })
        expect(step_def.panel_fields[2]).to eq({
          name: :notify,
          type: :boolean,
          options: { default: true }
        })
      end

      it 'returns panel fields when called without block' do
        step_def.instance_variable_set(:@panel_fields, [{ name: :test, type: :text, options: {} }])
        expect(step_def.panel).to eq([{ name: :test, type: :text, options: {} }])
      end
    end

    describe '#on_submit' do
      it 'stores the on_submit handler' do
        handler = proc { |fields, user| "processed" }
        step_def.on_submit(&handler)
        expect(step_def.on_submit_handler).to eq(handler)
      end

      it 'returns the handler when called without block' do
        handler = proc { |fields, user| "processed" }
        step_def.instance_variable_set(:@on_submit_handler, handler)
        expect(step_def.on_submit).to eq(handler)
      end
    end

    describe '#has_panel?' do
      it 'returns true when panel fields are defined' do
        step_def.panel do
          field :test, as: :text
        end
        expect(step_def.has_panel?).to be true
      end

      it 'returns false when no panel fields are defined' do
        expect(step_def.has_panel?).to be false
      end
    end

    describe '#has_on_submit_handler?' do
      it 'returns true when on_submit handler is defined' do
        step_def.on_submit { |fields, user| }
        expect(step_def.has_on_submit_handler?).to be true
      end

      it 'returns false when no on_submit handler is defined' do
        expect(step_def.has_on_submit_handler?).to be false
      end
    end
  end

  describe 'integrated step workflow with panels and form submission' do
    let(:integrated_workflow_class) do
      Class.new(described_class) do
        step :draft do
          describe 'Document is being drafted'
          action :submit_for_review, to: :review
          
          panel do
            field :title, as: :text, required: true
            field :content, as: :textarea, required: true
            field :category, as: :select, options: ['news', 'blog', 'announcement']
            field :urgent, as: :boolean, default: false
          end

          on_submit do |fields, user|
            # Update workflowable with form data
            workflowable.update!(
              title: fields[:title],
              content: fields[:content],
              category: fields[:category]
            )

            # Update workflow context
            update_context(
              submitted_by: user.id,
              submitted_at: Time.current,
              urgent: fields[:urgent]
            )

            # Perform the transition
            perform_action(:submit_for_review, user: user)
          end
        end

        step :review do
          describe 'Document under review'
          action :approve, to: :approved
          action :reject, to: :rejected

          panel do
            field :reviewer_comments, as: :textarea, required: true
            field :quality_score, as: :number, min: 1, max: 10
          end

          on_submit do |fields, user|
            update_context(
              reviewed_by: user.id,
              reviewer_comments: fields[:reviewer_comments],
              quality_score: fields[:quality_score]
            )

            if fields[:quality_score] >= 7
              perform_action(:approve, user: user)
            else
              perform_action(:reject, user: user)
            end
          end
        end

        step :approved
        step :rejected
      end
    end

    it 'defines steps with panels' do
      draft_step = integrated_workflow_class.find_step(:draft)
      expect(draft_step.has_panel?).to be true
      expect(draft_step.panel_fields.length).to eq(4)
      expect(draft_step.panel_fields.map { |f| f[:name] }).to eq([:title, :content, :category, :urgent])
    end

    it 'defines steps with on_submit handlers' do
      draft_step = integrated_workflow_class.find_step(:draft)
      expect(draft_step.has_on_submit_handler?).to be true
      expect(draft_step.on_submit_handler).to be_a(Proc)
    end

    it 'allows steps without panels or handlers' do
      approved_step = integrated_workflow_class.find_step(:approved)
      expect(approved_step.has_panel?).to be false
      expect(approved_step.has_on_submit_handler?).to be false
    end
  end

  describe 'workflow instance methods for on_submit' do
    let(:workflowable) { double('workflowable') }
    let(:execution) { double('execution', context_data: { initial: true }, workflowable: workflowable) }
    let(:workflow_instance) { test_workflow_class.new(execution) }
    let(:user) { double('user', id: 1) }

    describe '#perform_action' do
      it 'calls perform_action on execution with correct parameters' do
        expect(execution).to receive(:perform_action).with(
          :submit,
          user: user,
          additional_context: { notes: 'test' }
        )

        workflow_instance.perform_action(:submit, user: user, additional_context: { notes: 'test' })
      end

      it 'raises error when no execution is available' do
        instance_without_execution = test_workflow_class.new(nil)
        expect {
          instance_without_execution.perform_action(:submit, user: user)
        }.to raise_error(Avo::Workflows::Error, /no workflow execution available/)
      end
    end

    describe '#context' do
      it 'returns execution context data' do
        expect(workflow_instance.context).to eq({ initial: true })
      end

      it 'returns empty hash when no execution' do
        instance_without_execution = test_workflow_class.new(nil)
        expect(instance_without_execution.context).to eq({})
      end
    end

    describe '#update_context' do
      it 'calls update_context! on execution' do
        new_data = { updated: true }
        expect(execution).to receive(:update_context!).with(new_data)
        
        workflow_instance.update_context(new_data)
      end

      it 'raises error when no execution is available' do
        instance_without_execution = test_workflow_class.new(nil)
        expect {
          instance_without_execution.update_context({ test: true })
        }.to raise_error(Avo::Workflows::Error, /no workflow execution available/)
      end
    end

    describe '#workflowable' do
      it 'returns the workflowable object from execution' do
        expect(workflow_instance.workflowable).to eq(workflowable)
      end

      it 'returns nil when no execution' do
        instance_without_execution = test_workflow_class.new(nil)
        expect(instance_without_execution.workflowable).to be_nil
      end
    end
  end
end