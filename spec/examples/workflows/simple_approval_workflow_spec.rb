# frozen_string_literal: true

require 'rails_helper'
require_relative '../../../examples/workflows/simple_approval_workflow'

RSpec.describe SimpleApprovalWorkflow do
  let(:user) { User.create!(name: 'Test Author', email: 'author@example.com') }
  let(:reviewer) { User.create!(name: 'Test Reviewer', email: 'reviewer@example.com') }
  let(:document) do
    Post.create!(
      title: 'Test Document',
      content: 'Initial content for testing',
      user: user
    )
  end

  describe 'workflow definition' do
    it 'defines all required steps' do
      expect(described_class.step_names).to eq([:draft, :review, :approved, :rejected])
    end

    it 'validates workflow definition' do
      errors = described_class.validate_definition
      expect(errors).to be_empty
    end

    it 'identifies final steps correctly' do
      expect(described_class.final_steps).to eq([:approved])
    end
  end

  describe 'step panels and handlers' do
    it 'defines panels for interactive steps' do
      draft_step = described_class.find_step(:draft)
      review_step = described_class.find_step(:review)
      rejected_step = described_class.find_step(:rejected)
      
      expect(draft_step.has_panel?).to be true
      expect(review_step.has_panel?).to be true
      expect(rejected_step.has_panel?).to be true
      
      # Check draft panel fields
      draft_fields = draft_step.panel_fields.map { |f| f[:name] }
      expect(draft_fields).to include(:title, :content, :category, :urgent, :action_choice)
      
      # Check review panel fields
      review_fields = review_step.panel_fields.map { |f| f[:name] }
      expect(review_fields).to include(:reviewer_comments, :quality_score, :review_decision)
    end

    it 'defines on_submit handlers for interactive steps' do
      draft_step = described_class.find_step(:draft)
      review_step = described_class.find_step(:review)
      rejected_step = described_class.find_step(:rejected)
      
      expect(draft_step.has_on_submit_handler?).to be true
      expect(review_step.has_on_submit_handler?).to be true
      expect(rejected_step.has_on_submit_handler?).to be true
    end

    it 'has no panel for final approved step' do
      approved_step = described_class.find_step(:approved)
      expect(approved_step.has_panel?).to be false
      expect(approved_step.has_on_submit_handler?).to be false
    end
  end

  describe 'workflow execution' do
    let(:execution) do
      described_class.create_execution_for(
        document,
        assigned_to: user,
        initial_context: { created_by: user.id }
      )
    end
    let(:workflow_instance) { described_class.new(execution) }

    it 'starts in draft step' do
      expect(execution.current_step).to eq('draft')
    end

    describe 'draft step form processing' do
      it 'processes submit for review' do
        form_data = {
          title: 'Updated Document Title',
          content: 'This is the updated content for the document',
          category: 'blog',
          tags: 'test, example, demo',
          urgent: false,
          action_choice: 'submit_for_review'
        }

        draft_step = described_class.find_step(:draft)
        expect {
          workflow_instance.instance_exec(form_data, user, &draft_step.on_submit_handler)
        }.to change { execution.reload.current_step }.from('draft').to('review')

        # Verify document was updated
        document.reload
        expect(document.title).to eq('Updated Document Title')
        expect(document.content).to eq('This is the updated content for the document')

        # Verify context was updated
        context = execution.reload.context_data
        expect(context['category']).to eq('blog')
        expect(context['tags']).to eq(['test', 'example', 'demo'])
        expect(context['urgent']).to be false
        expect(context['priority']).to eq('normal')
        expect(context['word_count']).to eq(8) # "This is the updated content for the document" = 8 words
      end

      it 'processes urgent submit for review' do
        form_data = {
          title: 'Urgent Alert',
          content: 'Breaking news alert',
          category: 'news',
          urgent: true,
          action_choice: 'submit_for_review'
        }

        draft_step = described_class.find_step(:draft)
        workflow_instance.instance_exec(form_data, user, &draft_step.on_submit_handler)

        context = execution.reload.context_data
        expect(context['priority']).to eq('high')
        expect(context['urgent']).to be true
      end

      it 'processes save draft' do
        form_data = {
          title: 'Work in Progress',
          content: 'Still working on this',
          category: 'blog',
          urgent: false,
          action_choice: 'save_draft'
        }

        draft_step = described_class.find_step(:draft)
        workflow_instance.instance_exec(form_data, user, &draft_step.on_submit_handler)

        # Should stay in draft
        expect(execution.reload.current_step).to eq('draft')
        
        # But context should be updated
        context = execution.reload.context_data
        expect(context['category']).to eq('blog')
      end

      it 'raises error for missing required fields' do
        form_data = {
          title: '',  # Missing
          content: 'Some content',
          action_choice: 'submit_for_review'
        }

        draft_step = described_class.find_step(:draft)
        expect {
          workflow_instance.instance_exec(form_data, user, &draft_step.on_submit_handler)
        }.to raise_error('Title and content are required')
      end
    end

    describe 'review step form processing' do
      before do
        execution.update!(current_step: 'review')
        execution.update_context!({
          submitted_by: user.id,
          category: 'blog',
          priority: 'normal'
        })
      end

      it 'processes approval for high quality document' do
        form_data = {
          reviewer_comments: 'Excellent document, well written and informative',
          quality_score: 9,
          grammar_check: true,
          factual_accuracy: true,
          review_decision: 'approve'
        }

        review_step = described_class.find_step(:review)
        expect {
          workflow_instance.instance_exec(form_data, reviewer, &review_step.on_submit_handler)
        }.to change { execution.reload.current_step }.from('review').to('approved')

        # Verify review context
        context = execution.reload.context_data
        expect(context['reviewed_by']).to eq(reviewer.id)
        expect(context['quality_score']).to eq(9)
        expect(context['reviewer_comments']).to eq('Excellent document, well written and informative')
      end

      it 'processes rejection' do
        form_data = {
          reviewer_comments: 'Document needs significant improvements',
          quality_score: 3,
          grammar_check: false,
          factual_accuracy: true,
          review_decision: 'reject'
        }

        review_step = described_class.find_step(:review)
        expect {
          workflow_instance.instance_exec(form_data, reviewer, &review_step.on_submit_handler)
        }.to change { execution.reload.current_step }.from('review').to('rejected')
      end

      it 'processes request for changes' do
        form_data = {
          reviewer_comments: 'Good content but needs minor revisions',
          quality_score: 6,
          grammar_check: true,
          factual_accuracy: true,
          review_decision: 'request_changes'
        }

        review_step = described_class.find_step(:review)
        expect {
          workflow_instance.instance_exec(form_data, reviewer, &review_step.on_submit_handler)
        }.to change { execution.reload.current_step }.from('review').to('draft')
      end

      it 'raises error when trying to approve low quality document' do
        form_data = {
          reviewer_comments: 'Quality too low',
          quality_score: 5,  # Below threshold
          grammar_check: true,
          factual_accuracy: true,
          review_decision: 'approve'
        }

        review_step = described_class.find_step(:review)
        expect {
          workflow_instance.instance_exec(form_data, reviewer, &review_step.on_submit_handler)
        }.to raise_error(/Cannot approve.*Quality score must be 7/)
      end
    end

    describe 'rejected step form processing' do
      before do
        execution.update!(current_step: 'rejected')
      end

      it 'processes restart with content kept' do
        form_data = {
          rejection_reason: 'Need to address reviewer feedback',
          keep_draft_content: true
        }

        rejected_step = described_class.find_step(:rejected)
        expect {
          workflow_instance.instance_exec(form_data, user, &rejected_step.on_submit_handler)
        }.to change { execution.reload.current_step }.from('rejected').to('draft')

        # Content should be kept
        document.reload
        expect(document.content).to eq('Initial content for testing')

        # Restart context should be recorded
        context = execution.reload.context_data
        expect(context['restarted_by']).to eq(user.id)
        expect(context['content_kept']).to be true
      end

      it 'processes restart with content cleared' do
        form_data = {
          rejection_reason: 'Starting completely over',
          keep_draft_content: false
        }

        rejected_step = described_class.find_step(:rejected)
        workflow_instance.instance_exec(form_data, user, &rejected_step.on_submit_handler)

        # Content should be cleared
        document.reload
        expect(document.content).to eq('')

        # Restart context should be recorded
        context = execution.reload.context_data
        expect(context['content_kept']).to be false
      end
    end
  end

  describe 'field validation and types' do
    it 'defines proper field types and options' do
      draft_step = described_class.find_step(:draft)
      
      # Text field
      title_field = draft_step.panel_fields.find { |f| f[:name] == :title }
      expect(title_field[:type]).to eq(:text)
      expect(title_field[:options][:required]).to be true
      
      # Textarea field
      content_field = draft_step.panel_fields.find { |f| f[:name] == :content }
      expect(content_field[:type]).to eq(:textarea)
      expect(content_field[:options][:required]).to be true
      
      # Select field
      category_field = draft_step.panel_fields.find { |f| f[:name] == :category }
      expect(category_field[:type]).to eq(:select)
      expect(category_field[:options][:options]).to include('blog', 'news', 'announcement', 'policy')
      
      # Boolean field
      urgent_field = draft_step.panel_fields.find { |f| f[:name] == :urgent }
      expect(urgent_field[:type]).to eq(:boolean)
      expect(urgent_field[:options][:default]).to be false
    end

    it 'defines number field with range validation' do
      review_step = described_class.find_step(:review)
      quality_field = review_step.panel_fields.find { |f| f[:name] == :quality_score }
      
      expect(quality_field[:type]).to eq(:number)
      expect(quality_field[:options][:min]).to eq(1)
      expect(quality_field[:options][:max]).to eq(10)
      expect(quality_field[:options][:required]).to be true
    end
  end
end