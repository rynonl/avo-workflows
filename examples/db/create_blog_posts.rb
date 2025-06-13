# frozen_string_literal: true

# Migration to create blog_posts table for workflow examples
#
# This demonstrates a realistic domain model that integrates with workflows.
# The workflow tracks the approval process while the model handles business data.

class CreateBlogPosts < ActiveRecord::Migration[7.0]
  def change
    create_table :blog_posts do |t|
      # Core content fields
      t.string :title, null: false, limit: 200
      t.text :content, null: false
      t.text :excerpt, limit: 500
      t.string :tags, limit: 100

      # Author relationship (required)
      t.references :author, null: false, foreign_key: { to_table: :users }
      
      # Editor relationship (assigned during review)
      t.references :editor, null: true, foreign_key: { to_table: :users }

      # SEO and metadata
      t.string :slug, limit: 250
      t.string :meta_description, limit: 160
      t.string :featured_image_url
      
      # Publishing settings
      t.datetime :published_at
      t.boolean :featured, default: false
      t.integer :view_count, default: 0

      # Performance indexes
      t.index :slug, unique: true
      t.index :published_at
      t.index [:author_id, :created_at]
      t.index :featured

      t.timestamps
    end

    # Add check constraint for content length (minimum 50 characters)
    add_check_constraint :blog_posts, "length(content) >= 50", name: "blog_posts_content_length_check"
    
    # Add check constraint for title length (minimum 5 characters)
    add_check_constraint :blog_posts, "length(title) >= 5", name: "blog_posts_title_length_check"
  end
end