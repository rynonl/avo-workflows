# frozen_string_literal: true

# Basic Blog Post Workflow Example
#
# This example demonstrates a simple 3-step approval process for blog posts.
# It showcases core workflow features in an immediately understandable context.
#
# Workflow Steps:
# 1. draft → author writes and submits for review
# 2. under_review → editor reviews and approves/rejects  
# 3. published → post goes live (final state)
#
# Key Features Demonstrated:
# - Step definitions with descriptions
# - Actions with target transitions
# - Step requirements and conditions
# - Context data management
# - User assignments
# - Final state handling
#
# Usage:
#   # Create a blog post
#   post = BlogPost.create!(title: "My Post", content: "Content here", author: user)
#   
#   # Start workflow
#   execution = BlogPostWorkflow.create_execution_for(post, assigned_to: author)
#   
#   # Submit for review
#   execution.perform_action(:submit_for_review, user: author)
#   
#   # Editor approves
#   execution.perform_action(:approve, user: editor, additional_context: { 
#     editor_notes: "Great post!" 
#   })

class BlogPostWorkflow < Avo::Workflows::Base
  # Step 1: Draft - Author writes the post
  step :draft do
    describe "Author is writing or revising the blog post"
    
    requirement "Post must have a title"
    requirement "Post must have content"
    requirement "Author must be assigned"
    
    # Author submits post for editorial review
    action :submit_for_review, 
           to: :under_review,
           description: "Send post to editor for review",
           condition: ->(context) { draft_ready_for_review?(context) }
    
    # Author saves progress without submitting
    action :save_draft, 
           to: :draft,
           description: "Save current progress"
  end

  # Step 2: Under Review - Editor reviews the post
  step :under_review do
    describe "Editor is reviewing the post for publication"
    
    requirement "Editor must be assigned"
    requirement "Post content must be complete"
    
    # Editor approves post for publication
    action :approve, 
           to: :published,
           description: "Approve post for publication",
           confirmation_required: true
    
    # Editor requests changes from author
    action :request_changes, 
           to: :draft,
           description: "Send back to author with feedback"
  end

  # Step 3: Published - Post is live (final state)
  step :published do
    describe "Post is published and visible to readers"
    
    # No actions - this is a final state
    # In a real system, you might have actions like:
    # - unpublish (to draft)
    # - archive
    # - promote/feature
  end

  private

  # Validates that a draft post is ready for review
  #
  # This method checks if a blog post meets the minimum requirements
  # for editorial review, including content length and required fields.
  #
  # @param context [Hash] the workflow execution context containing the post
  # @option context [Object] :workflowable the blog post being processed
  # @option context [Object] :post alternative key for the blog post
  # @option context [Boolean] :force_submit bypass validation (for testing)
  # @return [Boolean] true if post meets review criteria
  # @example
  #   context = { workflowable: blog_post }
  #   BlogPostWorkflow.draft_ready_for_review?(context) #=> true
  def self.draft_ready_for_review?(context)
    # In a real application, you might check:
    # - Post has minimum word count
    # - Required fields are filled
    # - Images are properly sized
    # - SEO metadata is complete
    
    return true if context[:force_submit] || context['force_submit'] # Allow override for testing
    
    # Basic validation - post must have title and substantial content
    # Note: workflowable might be the actual object or a hash (when loaded from JSON)
    post_data = context[:workflowable] || context['workflowable'] || context[:post] || context['post']
    return false unless post_data
    
    # Handle both object and hash cases
    if post_data.respond_to?(:title)
      # It's an object
      post_data.title.present? && 
      post_data.content.present? && 
      post_data.content.length >= 100
    elsif post_data.is_a?(Hash)
      # It's a hash from JSON storage
      title = post_data['title'] || post_data[:title]
      content = post_data['content'] || post_data[:content]
      title.to_s.length > 0 && 
      content.to_s.length >= 100
    else
      false
    end
  end
end