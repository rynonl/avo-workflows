# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BlogPost, type: :model do
  # Test data setup
  let(:author) { User.create!(name: 'Alice Author', email: 'alice@example.com') }
  let(:editor) { User.create!(name: 'Bob Editor', email: 'bob@example.com') }
  let(:valid_attributes) do
    {
      title: 'Test Blog Post',
      content: 'This is a comprehensive blog post with substantial content that meets our minimum requirements for length and quality.',
      author: author
    }
  end

  describe 'associations' do
    it 'belongs to author' do
      blog_post = BlogPost.new(valid_attributes)
      expect(blog_post.author).to eq(author)
    end

    it 'belongs to editor (optional)' do
      blog_post = BlogPost.new(valid_attributes)
      expect(blog_post.editor).to be_nil
      blog_post.editor = editor
      expect(blog_post.editor).to eq(editor)
    end

    it 'has one workflow execution' do
      blog_post = BlogPost.create!(valid_attributes)
      expect(blog_post.workflow_execution).to be_nil
      blog_post.start_workflow!(assigned_to: author)
      expect(blog_post.reload.workflow_execution).to be_present
    end
  end

  describe 'validations' do
    it 'validates presence of title' do
      blog_post = BlogPost.new(valid_attributes.merge(title: nil))
      expect(blog_post).not_to be_valid
      expect(blog_post.errors[:title]).to include("can't be blank")
    end

    it 'validates title length' do
      blog_post = BlogPost.new(valid_attributes.merge(title: 'a'))
      expect(blog_post).not_to be_valid
      expect(blog_post.errors[:title]).to include('is too short (minimum is 5 characters)')
    end

    it 'validates presence of content' do
      blog_post = BlogPost.new(valid_attributes.merge(content: nil))
      expect(blog_post).not_to be_valid
      expect(blog_post.errors[:content]).to include("can't be blank")
    end

    it 'validates content length' do
      blog_post = BlogPost.new(valid_attributes.merge(content: 'short'))
      expect(blog_post).not_to be_valid
      expect(blog_post.errors[:content]).to include('is too short (minimum is 50 characters)')
    end

    it 'validates presence of author' do
      blog_post = BlogPost.new(valid_attributes.merge(author: nil))
      expect(blog_post).not_to be_valid
      expect(blog_post.errors[:author]).to include("can't be blank")
    end

    it 'validates excerpt length' do
      long_excerpt = 'a' * 501
      blog_post = BlogPost.new(valid_attributes.merge(excerpt: long_excerpt))
      expect(blog_post).not_to be_valid
      expect(blog_post.errors[:excerpt]).to include('is too long (maximum is 500 characters)')
    end

    it 'validates tags length' do
      long_tags = 'a' * 101
      blog_post = BlogPost.new(valid_attributes.merge(tags: long_tags))
      expect(blog_post).not_to be_valid
      expect(blog_post.errors[:tags]).to include('is too long (maximum is 100 characters)')
    end

    it 'validates slug uniqueness' do
      BlogPost.create!(valid_attributes.merge(slug: 'unique-slug'))
      blog_post = BlogPost.new(valid_attributes.merge(title: 'Different Title', slug: 'unique-slug'))
      expect(blog_post).not_to be_valid
      expect(blog_post.errors[:slug]).to include('has already been taken')
    end
  end

  describe 'scopes' do
    let!(:draft_post) { BlogPost.create!(valid_attributes) }
    let!(:review_post) { BlogPost.create!(valid_attributes.merge(title: 'Review Post')) }
    let!(:published_post) { BlogPost.create!(valid_attributes.merge(title: 'Published Post')) }

    before do
      # Set up workflow executions for each post
      draft_post.start_workflow!(assigned_to: author)
      
      review_post.start_workflow!(assigned_to: author)
      review_post.submit_for_review!(user: author)
      
      published_post.start_workflow!(assigned_to: author)
      published_post.submit_for_review!(user: author)
      published_post.approve_for_publication!(editor: editor)
    end

    describe '.drafts' do
      it 'returns posts in draft state' do
        expect(BlogPost.drafts).to include(draft_post)
        expect(BlogPost.drafts).not_to include(review_post, published_post)
      end
    end

    describe '.under_review' do
      it 'returns posts under review' do
        expect(BlogPost.under_review).to include(review_post)
        expect(BlogPost.under_review).not_to include(draft_post, published_post)
      end
    end

    describe '.published' do
      it 'returns published posts' do
        expect(BlogPost.published).to include(published_post)
        expect(BlogPost.published).not_to include(draft_post, review_post)
      end
    end
  end

  describe 'workflow state methods' do
    let(:blog_post) { BlogPost.create!(valid_attributes) }

    context 'without workflow execution' do
      it 'returns false for all state checks' do
        expect(blog_post.draft?).to be false
        expect(blog_post.under_review?).to be false
        expect(blog_post.published?).to be false
      end

      it 'returns "No workflow" for status' do
        expect(blog_post.workflow_status).to eq('No workflow')
      end
    end

    context 'with workflow execution' do
      before { blog_post.start_workflow! }

      it 'correctly identifies draft state' do
        expect(blog_post.draft?).to be true
        expect(blog_post.under_review?).to be false
        expect(blog_post.published?).to be false
        expect(blog_post.workflow_status).to eq('Draft')
      end

      it 'correctly identifies under review state' do
        blog_post.submit_for_review!(user: author)
        expect(blog_post.draft?).to be false
        expect(blog_post.under_review?).to be true
        expect(blog_post.published?).to be false
        expect(blog_post.workflow_status).to eq('Under review')
      end

      it 'correctly identifies published state' do
        blog_post.submit_for_review!(user: author)
        blog_post.approve_for_publication!(editor: editor)
        expect(blog_post.draft?).to be false
        expect(blog_post.under_review?).to be false
        expect(blog_post.published?).to be true
        expect(blog_post.workflow_status).to eq('Published')
      end
    end
  end

  describe '#start_workflow!' do
    let(:blog_post) { BlogPost.create!(valid_attributes) }

    it 'creates workflow execution assigned to author by default' do
      execution = blog_post.start_workflow!
      expect(execution).to be_a(Avo::Workflows::WorkflowExecution)
      expect(execution.assigned_to).to eq(author)
      expect(execution.workflowable).to eq(blog_post)
    end

    it 'allows custom assignment' do
      execution = blog_post.start_workflow!(assigned_to: editor)
      expect(execution.assigned_to).to eq(editor)
    end

    it 'returns existing workflow if already present' do
      first_execution = blog_post.start_workflow!
      second_execution = blog_post.start_workflow!
      expect(second_execution).to eq(first_execution)
    end

    it 'includes initial context' do
      execution = blog_post.start_workflow!
      context = execution.context_data
      expect(context['post_title']).to eq('Test Blog Post')
      expect(context['author_id']).to eq(author.id)
      expect(context['word_count']).to be > 0
      expect(context['workflowable']).to be_a(Hash)
      expect(context['workflowable']['id']).to eq(blog_post.id)
    end
  end

  describe '#submit_for_review!' do
    let(:blog_post) { BlogPost.create!(valid_attributes) }

    it 'creates workflow if none exists' do
      expect(blog_post.workflow_execution).to be_nil
      blog_post.submit_for_review!(user: author)
      expect(blog_post.workflow_execution).to be_present
    end

    it 'transitions to under_review state' do
      blog_post.start_workflow!
      result = blog_post.submit_for_review!(user: author)
      expect(result).to be true
      expect(blog_post.workflow_execution.current_step).to eq('under_review')
    end

    it 'includes author notes in context' do
      blog_post.start_workflow!
      blog_post.submit_for_review!(user: author, notes: 'Please review quickly')
      expect(blog_post.workflow_execution.context_data['author_notes']).to eq('Please review quickly')
    end

    it 'fails with insufficient content' do
      short_post = BlogPost.new(title: 'Short Post', content: 'Too short', author: author)
      short_post.save(validate: false)
      short_post.start_workflow!
      result = short_post.submit_for_review!(user: author)
      expect(result).to be false
      expect(short_post.workflow_execution.current_step).to eq('draft')
    end
  end

  describe '#approve_for_publication!' do
    let(:blog_post) { BlogPost.create!(valid_attributes) }

    before do
      blog_post.start_workflow!
      blog_post.submit_for_review!(user: author)
    end

    it 'transitions to published state' do
      result = blog_post.approve_for_publication!(editor: editor)
      expect(result).to be true
      expect(blog_post.workflow_execution.current_step).to eq('published')
    end

    it 'assigns editor to post' do
      blog_post.approve_for_publication!(editor: editor)
      expect(blog_post.reload.editor).to eq(editor)
    end

    it 'includes editor notes in context' do
      blog_post.approve_for_publication!(editor: editor, notes: 'Excellent work!')
      expect(blog_post.workflow_execution.context_data['editor_notes']).to eq('Excellent work!')
    end

    it 'preserves existing editor assignment' do
      blog_post.update!(editor: editor)
      different_editor = User.create!(name: 'Carol', email: 'carol@example.com')
      blog_post.approve_for_publication!(editor: different_editor)
      expect(blog_post.reload.editor).to eq(editor) # Should not change
    end
  end

  describe '#request_changes!' do
    let(:blog_post) { BlogPost.create!(valid_attributes) }

    before do
      blog_post.start_workflow!
      blog_post.submit_for_review!(user: author)
    end

    it 'transitions back to draft state' do
      result = blog_post.request_changes!(editor: editor, feedback: 'Needs more detail')
      expect(result).to be true
      expect(blog_post.workflow_execution.current_step).to eq('draft')
    end

    it 'includes feedback in context' do
      blog_post.request_changes!(editor: editor, feedback: 'Please add examples')
      expect(blog_post.workflow_execution.context_data['editor_feedback']).to eq('Please add examples')
    end

    it 'requires feedback' do
      expect {
        blog_post.request_changes!(editor: editor, feedback: '')
      }.to raise_error(ArgumentError, 'Feedback is required when requesting changes')
    end
  end

  describe '#available_workflow_actions' do
    let(:blog_post) { BlogPost.create!(valid_attributes) }

    it 'returns empty array without workflow' do
      expect(blog_post.available_workflow_actions).to eq([])
    end

    it 'returns available actions with workflow' do
      blog_post.start_workflow!
      expect(blog_post.available_workflow_actions).to contain_exactly(:submit_for_review, :save_draft)
    end
  end

  describe '#workflow_history' do
    let(:blog_post) { BlogPost.create!(valid_attributes) }

    it 'returns empty array without workflow' do
      expect(blog_post.workflow_history).to eq([])
    end

    it 'returns history with workflow' do
      blog_post.start_workflow!
      blog_post.submit_for_review!(user: author)
      history = blog_post.workflow_history
      expect(history).not_to be_empty
      last_entry = history.last
      expect(last_entry['action']).to eq('submit_for_review')
      expect(last_entry['from_step']).to eq('draft')
      expect(last_entry['to_step']).to eq('under_review')
    end
  end
end