# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Integrated Step Workflow' do
  # Test workflow using the new integrated DSL
  before do
    # Define a proper constant for the test workflow
    stub_const('IntegratedTestWorkflow', Class.new(Avo::Workflows::Base) do

      step :draft do
        describe 'Document is being drafted'
        requirement 'Title must be present'
        requirement 'Content must be present'
        
        action :submit_for_review, to: :review
        action :save_draft, to: :draft
        
        panel do
          field :title, as: :text, required: true, label: 'Document Title'
          field :content, as: :textarea, required: true, label: 'Document Content'
          field :category, as: :select, options: ['news', 'blog', 'announcement'], required: true
          field :urgent, as: :boolean, default: false, label: 'Mark as Urgent'
          field :tags, as: :text, label: 'Tags (comma separated)'
        end

        on_submit do |fields, user|
          # Validate required fields
          if fields[:title].blank? || fields[:content].blank?
            raise 'Title and content are required'
          end

          # Update the workflowable object
          workflowable.update!(
            title: fields[:title],
            content: fields[:content]
            # Note: Post model doesn't have category or tags fields, so we'll store those in context
          )

          # Update workflow context with form data and metadata
          update_context(
            submitted_by: user.id,
            submitted_at: Time.current,
            urgent: fields[:urgent],
            word_count: fields[:content].split.length,
            category: fields[:category],
            tags: fields[:tags]
          )

          # Determine next action based on urgency
          if fields[:urgent]
            perform_action(:submit_for_review, user: user, additional_context: { priority: 'high' })
          else
            # For non-urgent, just save as draft for now
            perform_action(:save_draft, user: user)
          end
        end
      end

      step :review do
        describe 'Document under review by editor'
        requirement 'Document must be complete'
        requirement 'Editor must be assigned'
        
        action :approve, to: :approved
        action :reject, to: :rejected
        action :request_changes, to: :draft

        panel do
          field :reviewer_comments, as: :textarea, required: true, label: 'Review Comments'
          field :quality_score, as: :number, min: 1, max: 10, required: true, label: 'Quality Score'
          field :grammar_check, as: :boolean, default: true, label: 'Grammar Check Passed'
          field :action_choice, as: :select, options: ['approve', 'reject', 'request_changes'], required: true, label: 'Decision'
        end

        on_submit do |fields, user|
          # Update context with review data
          update_context(
            reviewed_by: user.id,
            reviewed_at: Time.current,
            reviewer_comments: fields[:reviewer_comments],
            quality_score: fields[:quality_score],
            grammar_check: fields[:grammar_check]
          )

          # Perform action based on reviewer's choice
          case fields[:action_choice]
          when 'approve'
            if fields[:quality_score] >= 7
              perform_action(:approve, user: user)
            else
              raise 'Quality score must be 7 or higher for approval'
            end
          when 'reject'
            perform_action(:reject, user: user)
          when 'request_changes'
            perform_action(:request_changes, user: user)
          else
            raise 'Invalid action choice'
          end
        end
      end

      step :approved do
        describe 'Document approved and ready for publication'
        # Final state - no actions
      end

      step :rejected do
        describe 'Document rejected'
        
        action :resubmit, to: :draft

        panel do
          field :resubmission_notes, as: :textarea, label: 'Resubmission Notes'
        end

        on_submit do |fields, user|
          update_context(
            resubmitted_by: user.id,
            resubmitted_at: Time.current,
            resubmission_notes: fields[:resubmission_notes]
          )

          perform_action(:resubmit, user: user)
        end
      end
    end)
  end

  let(:test_workflow_class) { IntegratedTestWorkflow }

  let(:user) { User.create!(name: 'Test User', email: 'test@example.com') }
  let(:document) do
    Post.create!(
      title: 'Initial Title',
      content: 'Initial content',
      user: user
    )
  end
  let(:execution) do
    test_workflow_class.create_execution_for(
      document,
      assigned_to: user,
      initial_context: { created_by: user.id }
    )
  end

  describe 'workflow definition validation' do
    it 'defines all steps correctly' do
      expect(test_workflow_class.step_names).to eq([:draft, :review, :approved, :rejected])
    end

    it 'identifies final steps' do
      expect(test_workflow_class.final_steps).to eq([:approved])
    end

    it 'validates workflow definition' do
      errors = test_workflow_class.validate_definition
      expect(errors).to be_empty
    end
  end

  describe 'panel definitions' do
    it 'defines panel fields for draft step' do
      draft_step = test_workflow_class.find_step(:draft)
      expect(draft_step.has_panel?).to be true
      expect(draft_step.panel_fields.length).to eq(5)
      
      field_names = draft_step.panel_fields.map { |f| f[:name] }
      expect(field_names).to eq([:title, :content, :category, :urgent, :tags])
    end

    it 'defines panel fields for review step' do
      review_step = test_workflow_class.find_step(:review)
      expect(review_step.has_panel?).to be true
      expect(review_step.panel_fields.length).to eq(4)
      
      field_names = review_step.panel_fields.map { |f| f[:name] }
      expect(field_names).to eq([:reviewer_comments, :quality_score, :grammar_check, :action_choice])
    end

    it 'defines panel fields for rejected step' do
      rejected_step = test_workflow_class.find_step(:rejected)
      expect(rejected_step.has_panel?).to be true
      expect(rejected_step.panel_fields.length).to eq(1)
      
      field = rejected_step.panel_fields.first
      expect(field[:name]).to eq(:resubmission_notes)
      expect(field[:type]).to eq(:textarea)
    end

    it 'has no panel for approved step' do
      approved_step = test_workflow_class.find_step(:approved)
      expect(approved_step.has_panel?).to be false
    end
  end

  describe 'on_submit handlers' do
    it 'defines on_submit handlers for interactive steps' do
      draft_step = test_workflow_class.find_step(:draft)
      review_step = test_workflow_class.find_step(:review)
      rejected_step = test_workflow_class.find_step(:rejected)
      
      expect(draft_step.has_on_submit_handler?).to be true
      expect(review_step.has_on_submit_handler?).to be true
      expect(rejected_step.has_on_submit_handler?).to be true
    end

    it 'has no on_submit handler for final steps' do
      approved_step = test_workflow_class.find_step(:approved)
      expect(approved_step.has_on_submit_handler?).to be false
    end
  end

  describe 'workflow execution with simulated form submission' do
    let(:workflow_instance) { test_workflow_class.new(execution) }

    it 'starts in draft step' do
      expect(execution.current_step).to eq('draft')
    end

    it 'provides access to workflow context and workflowable' do
      expect(workflow_instance.context['created_by']).to eq(user.id)
      expect(workflow_instance.workflowable).to eq(document)
    end

    context 'draft step form submission' do
      it 'processes urgent document submission' do
        # Simulate form submission
        form_data = {
          title: 'Urgent News Alert',
          content: 'Breaking news content that needs immediate attention',
          category: 'news',
          urgent: true,
          tags: 'breaking, urgent, alert'
        }

        # Execute on_submit handler
        draft_step = test_workflow_class.find_step(:draft)
        expect {
          workflow_instance.instance_exec(form_data, user, &draft_step.on_submit_handler)
        }.to change { execution.reload.current_step }.from('draft').to('review')

        # Verify workflowable was updated
        document.reload
        expect(document.title).to eq('Urgent News Alert')
        expect(document.content).to eq('Breaking news content that needs immediate attention')

        # Verify context was updated
        context = execution.reload.context_data
        expect(context['submitted_by']).to eq(user.id)
        expect(context['urgent']).to be true
        expect(context['word_count']).to eq(7) # "Breaking news content that needs immediate attention" = 7 words
        expect(context['category']).to eq('news')
        expect(context['priority']).to eq('high')
      end

      it 'processes non-urgent document as draft save' do
        form_data = {
          title: 'Regular Blog Post',
          content: 'This is regular content that can wait',
          category: 'blog',
          urgent: false,
          tags: 'regular, blog'
        }

        draft_step = test_workflow_class.find_step(:draft)
        workflow_instance.instance_exec(form_data, user, &draft_step.on_submit_handler)

        # Should stay in draft for non-urgent
        expect(execution.reload.current_step).to eq('draft')
        
        # But context should be updated
        context = execution.reload.context_data
        expect(context['urgent']).to be false
        expect(context['category']).to eq('blog')
      end

      it 'raises error for missing required fields' do
        form_data = {
          title: '',  # Missing required field
          content: 'Some content',
          category: 'blog',
          urgent: false
        }

        draft_step = test_workflow_class.find_step(:draft)
        expect {
          workflow_instance.instance_exec(form_data, user, &draft_step.on_submit_handler)
        }.to raise_error('Title and content are required')
      end
    end

    context 'review step form submission' do
      before do
        # Move to review step first
        execution.update!(current_step: 'review')
        execution.update_context!({
          submitted_by: user.id,
          urgent: true,
          category: 'news'
        })
      end

      it 'approves high-quality document' do
        form_data = {
          reviewer_comments: 'Excellent article, well written and informative',
          quality_score: 9,
          grammar_check: true,
          action_choice: 'approve'
        }

        review_step = test_workflow_class.find_step(:review)
        expect {
          workflow_instance.instance_exec(form_data, user, &review_step.on_submit_handler)
        }.to change { execution.reload.current_step }.from('review').to('approved')

        # Verify context includes review data
        context = execution.reload.context_data
        expect(context['reviewed_by']).to eq(user.id)
        expect(context['quality_score']).to eq(9)
        expect(context['reviewer_comments']).to eq('Excellent article, well written and informative')
      end

      it 'rejects document' do
        form_data = {
          reviewer_comments: 'Needs significant improvements',
          quality_score: 4,
          grammar_check: false,
          action_choice: 'reject'
        }

        review_step = test_workflow_class.find_step(:review)
        expect {
          workflow_instance.instance_exec(form_data, user, &review_step.on_submit_handler)
        }.to change { execution.reload.current_step }.from('review').to('rejected')
      end

      it 'requests changes' do
        form_data = {
          reviewer_comments: 'Good content but needs minor revisions',
          quality_score: 6,
          grammar_check: true,
          action_choice: 'request_changes'
        }

        review_step = test_workflow_class.find_step(:review)
        expect {
          workflow_instance.instance_exec(form_data, user, &review_step.on_submit_handler)
        }.to change { execution.reload.current_step }.from('review').to('draft')
      end

      it 'raises error when trying to approve low-quality document' do
        form_data = {
          reviewer_comments: 'Quality is too low for approval',
          quality_score: 5,  # Below threshold of 7
          grammar_check: true,
          action_choice: 'approve'
        }

        review_step = test_workflow_class.find_step(:review)
        expect {
          workflow_instance.instance_exec(form_data, user, &review_step.on_submit_handler)
        }.to raise_error('Quality score must be 7 or higher for approval')
      end
    end

    context 'rejected step form submission' do
      before do
        execution.update!(current_step: 'rejected')
      end

      it 'handles resubmission from rejected state' do
        form_data = {
          resubmission_notes: 'Addressed all reviewer feedback and improved content quality'
        }

        rejected_step = test_workflow_class.find_step(:rejected)
        expect {
          workflow_instance.instance_exec(form_data, user, &rejected_step.on_submit_handler)
        }.to change { execution.reload.current_step }.from('rejected').to('draft')

        # Verify resubmission context
        context = execution.reload.context_data
        expect(context['resubmitted_by']).to eq(user.id)
        expect(context['resubmission_notes']).to eq('Addressed all reviewer feedback and improved content quality')
      end
    end
  end

  describe 'field type validation and options' do
    it 'supports all field types with proper options' do
      draft_step = test_workflow_class.find_step(:draft)
      fields = draft_step.panel_fields

      # Text field
      title_field = fields.find { |f| f[:name] == :title }
      expect(title_field[:type]).to eq(:text)
      expect(title_field[:options][:required]).to be true
      expect(title_field[:options][:label]).to eq('Document Title')

      # Textarea field
      content_field = fields.find { |f| f[:name] == :content }
      expect(content_field[:type]).to eq(:textarea)
      expect(content_field[:options][:required]).to be true

      # Select field
      category_field = fields.find { |f| f[:name] == :category }
      expect(category_field[:type]).to eq(:select)
      expect(category_field[:options][:options]).to eq(['news', 'blog', 'announcement'])

      # Boolean field
      urgent_field = fields.find { |f| f[:name] == :urgent }
      expect(urgent_field[:type]).to eq(:boolean)
      expect(urgent_field[:options][:default]).to be false
    end

    it 'supports number field with validation' do
      review_step = test_workflow_class.find_step(:review)
      quality_field = review_step.panel_fields.find { |f| f[:name] == :quality_score }
      
      expect(quality_field[:type]).to eq(:number)
      expect(quality_field[:options][:min]).to eq(1)
      expect(quality_field[:options][:max]).to eq(10)
      expect(quality_field[:options][:required]).to be true
    end
  end
end