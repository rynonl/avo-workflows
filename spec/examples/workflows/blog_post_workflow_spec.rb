# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BlogPostWorkflow, type: :workflow do
  # Test data setup
  let(:author) { User.create!(name: 'Alice Author', email: 'alice@example.com') }
  let(:editor) { User.create!(name: 'Bob Editor', email: 'bob@example.com') }
  let(:blog_post) { BlogPost.create!(title: 'Test Post', content: 'A' * 200, author: author) }
  let(:workflow_execution) { blog_post.start_workflow!(assigned_to: author) }

  describe 'workflow definition' do
    it 'has the correct steps defined' do
      expect(BlogPostWorkflow.step_names).to eq([:draft, :under_review, :published])
    end

    it 'identifies correct initial step' do
      expect(BlogPostWorkflow.initial_step).to eq(:draft)
    end

    it 'identifies correct final steps' do
      expect(BlogPostWorkflow.final_steps).to eq([:published])
    end

    it 'passes workflow validation' do
      errors = BlogPostWorkflow.validate_definition
      expect(errors).to be_empty
    end
  end

  describe 'step definitions' do
    describe 'draft step' do
      let(:draft_step) { BlogPostWorkflow.find_step(:draft) }

      it 'has correct description' do
        expect(draft_step.description).to eq('Author is writing or revising the blog post')
      end

      it 'has required actions' do
        expect(draft_step.actions.keys).to contain_exactly(:submit_for_review, :save_draft)
      end

      it 'has proper requirements' do
        expect(draft_step.requirements).to include(
          'Post must have a title',
          'Post must have content',
          'Author must be assigned'
        )
      end

      it 'submit_for_review action has condition' do
        action_config = draft_step.actions[:submit_for_review]
        expect(action_config[:condition]).to be_a(Proc)
        expect(action_config[:description]).to eq('Send post to editor for review')
      end
    end

    describe 'under_review step' do
      let(:review_step) { BlogPostWorkflow.find_step(:under_review) }

      it 'has correct description' do
        expect(review_step.description).to eq('Editor is reviewing the post for publication')
      end

      it 'has required actions' do
        expect(review_step.actions.keys).to contain_exactly(:approve, :request_changes)
      end

      it 'approve action requires confirmation' do
        expect(review_step.confirmation_required?(:approve)).to be true
      end

      it 'request_changes action does not require confirmation' do
        expect(review_step.confirmation_required?(:request_changes)).to be false
      end
    end

    describe 'published step' do
      let(:published_step) { BlogPostWorkflow.find_step(:published) }

      it 'has correct description' do
        expect(published_step.description).to eq('Post is published and visible to readers')
      end

      it 'has no actions (final state)' do
        expect(published_step.actions).to be_empty
      end
    end
  end

  describe '.draft_ready_for_review?' do
    context 'with valid post' do
      it 'returns true when post meets criteria' do
        context = { workflowable: blog_post }
        expect(BlogPostWorkflow.send(:draft_ready_for_review?, context)).to be true
      end
    end

    context 'with short content' do
      let(:short_post) do
        post = BlogPost.new(title: 'Short', content: 'Too short', author: author)
        post.save(validate: false) # Skip validation for test
        post
      end

      it 'returns false when content is too short' do
        context = { workflowable: short_post }
        expect(BlogPostWorkflow.send(:draft_ready_for_review?, context)).to be false
      end
    end

    context 'with force_submit flag' do
      let(:short_post) do
        post = BlogPost.new(title: 'Short', content: 'Too short', author: author)
        post.save(validate: false) # Skip validation for test
        post
      end

      it 'returns true when force_submit is enabled' do
        context = { workflowable: short_post, force_submit: true }
        expect(BlogPostWorkflow.send(:draft_ready_for_review?, context)).to be true
      end
    end

    context 'with missing post' do
      it 'returns false when no post in context' do
        context = {}
        expect(BlogPostWorkflow.send(:draft_ready_for_review?, context)).to be false
      end
    end
  end

  describe 'workflow execution' do
    describe 'initial state' do
      it 'starts in draft step' do
        expect(workflow_execution.current_step).to eq('draft')
      end

      it 'is assigned to the author' do
        expect(workflow_execution.assigned_to).to eq(author)
      end

      it 'has initial context' do
        context = workflow_execution.context_data
        expect(context['post_title']).to eq('Test Post')
        expect(context['author_id']).to eq(author.id)
        expect(context['word_count']).to eq(1)
        expect(context['workflowable']).to be_a(Hash)
        expect(context['workflowable']['id']).to eq(blog_post.id)
      end
    end

    describe 'available actions' do
      it 'shows correct actions for draft step' do
        expect(workflow_execution.available_actions).to contain_exactly(:submit_for_review, :save_draft)
      end
    end

    describe 'action execution' do
      describe 'submit_for_review action' do
        context 'with valid post' do
          it 'transitions to under_review' do
            success = workflow_execution.perform_action(:submit_for_review, user: author)
            expect(success).to be true
            expect(workflow_execution.current_step).to eq('under_review')
          end

          it 'records transition in history' do
            workflow_execution.perform_action(:submit_for_review, user: author)
            history = workflow_execution.step_history
            expect(history).not_to be_empty
            last_entry = history.last
            expect(last_entry['action']).to eq('submit_for_review')
            expect(last_entry['from_step']).to eq('draft')
            expect(last_entry['to_step']).to eq('under_review')
            expect(last_entry['user_id']).to eq(author.id)
          end
        end

        context 'with short content' do
          let(:short_post) do
            post = BlogPost.new(title: 'Short', content: 'Too short', author: author)
            post.save(validate: false)
            post
          end
          let(:short_execution) { short_post.start_workflow!(assigned_to: author) }

          it 'fails validation and stays in draft' do
            success = short_execution.perform_action(:submit_for_review, user: author)
            expect(success).to be false
            expect(short_execution.current_step).to eq('draft')
          end
        end
      end

      describe 'save_draft action' do
        it 'stays in draft step' do
          workflow_execution.perform_action(:save_draft, user: author)
          expect(workflow_execution.current_step).to eq('draft')
        end
      end
    end

    describe 'review process' do
      before do
        workflow_execution.perform_action(:submit_for_review, user: author)
      end

      it 'shows correct actions for under_review step' do
        expect(workflow_execution.available_actions).to contain_exactly(:approve, :request_changes)
      end

      describe 'approve action' do
        it 'transitions to published' do
          success = workflow_execution.perform_action(:approve, user: editor, 
                                                     additional_context: { editor_notes: 'Looks great!' })
          expect(success).to be true
          expect(workflow_execution.current_step).to eq('published')
        end

        it 'records editor notes in context' do
          workflow_execution.perform_action(:approve, user: editor, 
                                           additional_context: { editor_notes: 'Excellent work!' })
          expect(workflow_execution.context_data['editor_notes']).to eq('Excellent work!')
        end
      end

      describe 'request_changes action' do
        it 'transitions back to draft' do
          success = workflow_execution.perform_action(:request_changes, user: editor,
                                                     additional_context: { feedback: 'Needs more detail' })
          expect(success).to be true
          expect(workflow_execution.current_step).to eq('draft')
        end

        it 'preserves context from review cycle' do
          workflow_execution.perform_action(:request_changes, user: editor,
                                           additional_context: { feedback: 'Please add examples' })
          expect(workflow_execution.context_data['feedback']).to eq('Please add examples')
        end
      end
    end

    describe 'published state' do
      before do
        workflow_execution.perform_action(:submit_for_review, user: author)
        workflow_execution.perform_action(:approve, user: editor)
      end

      it 'has no available actions' do
        expect(workflow_execution.available_actions).to be_empty
      end

      it 'is marked as completed' do
        expect(workflow_execution.status).to eq('completed')
      end
    end
  end

  describe 'error handling' do
    it 'handles invalid actions gracefully' do
      success = workflow_execution.perform_action(:invalid_action, user: author)
      expect(success).to be false
      expect(workflow_execution.current_step).to eq('draft')
    end

    it 'handles missing user parameter' do
      expect {
        workflow_execution.perform_action(:submit_for_review)
      }.not_to raise_error
    end
  end

  describe 'context management' do
    it 'preserves context across transitions' do
      initial_context = workflow_execution.context_data.dup
      
      workflow_execution.perform_action(:submit_for_review, user: author, 
                                       additional_context: { author_notes: 'Please review quickly' })
      
      # Should preserve initial context and add new data
      expect(workflow_execution.context_data).to include(initial_context)
      expect(workflow_execution.context_data['author_notes']).to eq('Please review quickly')
    end

    it 'tracks user actions in context' do
      workflow_execution.perform_action(:submit_for_review, user: author)
      
      # Check that the user who performed the action is recorded
      history = workflow_execution.step_history
      last_entry = history.last
      expect(last_entry['user_id']).to eq(author.id)
      expect(last_entry['user_type']).to eq('User')
    end
  end
end