# Avo Integration Guide

This guide covers the complete integration of Avo Workflows with the Avo admin interface, including all available components, fields, panels, and actions.

## Overview

Avo Workflows provides native integration with Avo through:

- **Workflow Fields** - Display workflow status and actions in resources
- **Workflow Panels** - Rich workflow information panels  
- **Workflow Actions** - Execute workflow actions from Avo interface
- **Workflow Filters** - Filter resources by workflow state
- **Resource Mixins** - Easy integration helpers

## Quick Setup

### 1. Basic Resource Integration

```ruby
# app/avo/resources/document_resource.rb
class DocumentResource < Avo::BaseResource
  include Avo::Workflows::ResourceMethods
  
  # Basic fields
  field :title, as: :text
  field :content, as: :textarea
  
  # Workflow integration fields
  field :workflow_status, as: :workflow_progress
  field :workflow_actions, as: :workflow_actions
  
  # Workflow panels
  panel :workflow_details, as: :workflow_step_panel
  panel :workflow_history, as: :workflow_history_panel
  panel :workflow_context, as: :workflow_context_panel
  
  # Workflow filters
  filter :workflow_class, as: :workflow_class_filter
  filter :current_step, as: :current_step_filter
  filter :workflow_status, as: :status_filter
  
  # Workflow actions
  action :start_approval_workflow, as: :workflow_action
  action :assign_workflow, as: :assign_workflow
end
```

### 2. Model Setup

```ruby
# app/models/document.rb
class Document < ApplicationRecord
  include Avo::Workflows::WorkflowMethods
  
  validates :title, presence: true
  validates :content, presence: true
  
  # Optional: Define available workflows
  def available_workflows
    [DocumentApprovalWorkflow, UrgentApprovalWorkflow]
  end
end
```

## Workflow Fields

### Workflow Progress Field

Displays current workflow step with visual progress indicator.

```ruby
field :workflow_status, as: :workflow_progress, 
      name: "Approval Status",
      show_percentage: true,
      color_coding: true
```

**Features:**
- Progress bar showing completion percentage
- Color-coded status (green=completed, yellow=in-progress, red=failed)
- Step-by-step breakdown
- Time tracking display

**Customization Options:**
```ruby
field :workflow_status, as: :workflow_progress do |field|
  field.show_percentage = true
  field.show_time_estimates = true
  field.color_scheme = :status_based # or :step_based
  field.display_format = :detailed   # or :compact
end
```

### Workflow Actions Field

Interactive action buttons for performing workflow actions.

```ruby
field :workflow_actions, as: :workflow_actions,
      name: "Available Actions",
      confirm_dangerous: true,
      show_conditions: true
```

**Features:**
- Context-aware action buttons
- Permission checking
- Confirmation dialogs for destructive actions
- Conditional action display
- Bulk action support

**Advanced Configuration:**
```ruby
field :workflow_actions, as: :workflow_actions do |field|
  field.confirm_dangerous = true
  field.show_action_descriptions = true
  field.group_by_category = true
  field.max_actions_displayed = 5
  field.overflow_behavior = :dropdown
  
  # Custom action rendering
  field.action_renderer = ->(action, execution) do
    {
      label: action.humanized_name,
      variant: action.dangerous? ? :danger : :primary,
      confirm_message: action.confirmation_message
    }
  end
end
```

### Workflow Timeline Field

Visual timeline showing workflow progression.

```ruby
field :workflow_timeline, as: :workflow_timeline,
      show_future_steps: true,
      include_context_changes: true
```

## Workflow Panels

### Workflow Step Panel

Detailed view of current workflow step and available actions.

```ruby
panel :current_workflow, as: :workflow_step_panel do |panel|
  panel.name = "Current Workflow Status"
  panel.description = "Shows the current step and available actions"
  panel.show_step_details = true
  panel.show_action_history = true
  panel.show_assigned_users = true
end
```

**Panel Content:**
- Current step information
- Available actions with descriptions
- Assigned users and roles
- Step validation status
- Estimated completion time

### Workflow History Panel

Complete history of workflow execution.

```ruby
panel :workflow_history, as: :workflow_history_panel do |panel|
  panel.name = "Workflow History"
  panel.show_context_changes = true
  panel.show_user_actions = true
  panel.show_system_events = true
  panel.paginate = true
  panel.items_per_page = 20
end
```

**Features:**
- Chronological action history
- User attribution for each action
- Context changes tracking
- System event logging
- Performance metrics
- Filtering and search

### Workflow Context Panel

Display and edit workflow context data.

```ruby
panel :workflow_context, as: :workflow_context_panel do |panel|
  panel.name = "Workflow Data"
  panel.editable_fields = [:priority, :notes, :assigned_team]
  panel.readonly_fields = [:created_at, :system_data]
  panel.show_json_view = true
end
```

**Context Management:**
- Key-value display of context data
- Editable context fields (with permissions)
- JSON view for complex data
- Change tracking
- Validation on context updates

## Workflow Actions

### Standard Workflow Actions

Execute workflow actions directly from Avo interface.

```ruby
# app/avo/actions/approve_document_action.rb
class ApproveDocumentAction < Avo::BaseAction
  include Avo::Workflows::ActionMethods
  
  self.name = "Approve Document"
  self.message = "Document approved successfully"
  self.confirm_button_label = "Approve"
  
  # Define which workflow action to execute
  self.workflow_action = :approve
  
  # Custom fields for the action
  field :comments, as: :textarea, help: "Optional approval comments"
  field :notify_author, as: :boolean, default: true
  
  def handle(**args)
    perform_workflow_action(
      action: :approve,
      user: current_user,
      context: {
        approval_comments: args[:fields][:comments],
        notify_author: args[:fields][:notify_author],
        approved_at: Time.current
      }
    )
  end
end
```

### Assign Workflow Action

Special action for assigning workflows to users.

```ruby
action :assign_workflow, as: :assign_workflow do |action|
  action.name = "Assign Workflow"
  action.icon = "heroicons/outline/user-plus"
  action.available_workflows = [:DocumentApprovalWorkflow, :UrgentApprovalWorkflow]
  action.default_assignee = :current_user
end
```

### Bulk Workflow Actions

Perform actions on multiple records.

```ruby
# app/avo/actions/bulk_approve_action.rb
class BulkApproveAction < Avo::BaseAction
  include Avo::Workflows::BulkActionMethods
  
  self.name = "Bulk Approve"
  self.standalone = false # Only available on index page
  
  def handle(**args)
    args[:models].each do |model|
      next unless model.workflow_execution&.available_actions&.include?(:approve)
      
      perform_workflow_action_on(
        model: model,
        action: :approve,
        user: current_user,
        context: { bulk_approved: true }
      )
    end
    
    succeed "#{args[:models].count} documents approved"
  end
end
```

## Workflow Filters

### Workflow Class Filter

Filter resources by workflow type.

```ruby
filter :workflow_type, as: :workflow_class_filter do |filter|
  filter.name = "Workflow Type"
  filter.options = {
    'Document Approval' => 'DocumentApprovalWorkflow',
    'Urgent Approval' => 'UrgentApprovalWorkflow',
    'Review Process' => 'ReviewWorkflow'
  }
end
```

### Current Step Filter

Filter by workflow step.

```ruby
filter :workflow_step, as: :current_step_filter do |filter|
  filter.name = "Current Step"
  filter.dynamic_options = true # Load options from actual workflow data
  filter.include_empty = true   # Include records without workflows
end
```

### Status Filter

Filter by workflow status.

```ruby
filter :workflow_status, as: :status_filter do |filter|
  filter.name = "Status"
  filter.options = {
    'Active' => 'active',
    'Completed' => 'completed', 
    'Failed' => 'failed',
    'Paused' => 'paused'
  }
end
```

## Advanced Components

### Workflow Visualizer

Interactive workflow diagram showing all steps and transitions.

```ruby
# In your resource or custom tool
component :workflow_diagram, as: :workflow_visualizer do |component|
  component.workflow_class = DocumentApprovalWorkflow
  component.highlight_current_step = true
  component.show_action_details = true
  component.interactive = true
  component.layout = :horizontal # or :vertical
end
```

**Features:**
- Interactive step nodes
- Action arrows with conditions
- Current step highlighting
- Zoom and pan functionality
- Export to image/PDF

### Custom Workflow Dashboard

Create workflow-specific dashboards.

```ruby
# app/avo/dashboards/workflow_dashboard.rb
class WorkflowDashboard < Avo::Dashboards::BaseDashboard
  self.name = "Workflow Overview"
  self.description = "Monitor all active workflows"
  
  # Metrics cards
  card :total_active_workflows, as: :metric_card
  card :completion_rate, as: :metric_card
  card :average_processing_time, as: :metric_card
  
  # Charts
  card :workflow_status_chart, as: :chart_card do |card|
    card.chart_type = :pie
    card.data = workflow_status_data
  end
  
  card :workflow_timeline, as: :chart_card do |card|
    card.chart_type = :line
    card.data = workflow_timeline_data
  end
  
  # Recent activity
  card :recent_workflow_activity, as: :table_card do |card|
    card.limit = 10
    card.data = recent_workflow_executions
  end
end
```

## Permissions Integration

### Resource-Level Permissions

```ruby
class DocumentResource < Avo::BaseResource
  include Avo::Workflows::ResourceMethods
  
  # Workflow-aware permissions
  def can_view?
    current_user.can_view_document?(record) ||
    current_user.assigned_to_workflow?(record.workflow_execution)
  end
  
  def can_edit?
    # Allow editing if user can perform workflow actions
    record.workflow_execution&.available_actions_for_user(current_user)&.any?
  end
  
  def can_delete?
    # Only allow deletion if workflow is not active
    !record.workflow_execution&.active?
  end
end
```

### Action-Level Permissions

```ruby
class ApproveDocumentAction < Avo::BaseAction
  def visible?
    # Only show for users who can approve
    resource.workflow_execution&.can_perform_action?(:approve, current_user)
  end
  
  def handle(**args)
    # Double-check permissions
    unless can_perform_workflow_action?(:approve, current_user)
      error "You don't have permission to approve this document"
      return
    end
    
    perform_workflow_action(action: :approve, user: current_user)
  end
end
```

## Configuration

### Global Workflow Configuration

```ruby
# config/initializers/avo_workflows.rb
Avo::Workflows.configure do |config|
  # Avo integration settings
  config.avo_integration = true
  config.default_workflow_field_options = {
    show_progress_bar: true,
    color_coding: true
  }
  
  # Action confirmation settings
  config.confirm_dangerous_actions = true
  config.action_confirmation_threshold = :medium # :low, :medium, :high
  
  # Performance settings
  config.cache_workflow_data = true
  config.eager_load_associations = [:workflowable, :user]
end
```

### Resource-Specific Configuration

```ruby
class DocumentResource < Avo::BaseResource
  include Avo::Workflows::ResourceMethods
  
  # Configure workflow integration
  workflow_config do |config|
    config.show_workflow_tabs = true
    config.default_workflow_class = DocumentApprovalWorkflow
    config.auto_assign_to_current_user = true
    config.enable_bulk_actions = true
  end
end
```

## Styling and Theming

### Custom CSS for Workflow Components

```scss
// app/assets/stylesheets/avo/workflows.scss

// Workflow progress styling
.workflow-progress {
  .progress-bar {
    background: linear-gradient(90deg, #10b981 0%, #3b82f6 100%);
  }
  
  .step-indicator {
    &.completed { color: #10b981; }
    &.current { color: #3b82f6; }
    &.pending { color: #6b7280; }
  }
}

// Workflow action buttons
.workflow-actions {
  .action-button {
    &.primary { @apply bg-blue-600 hover:bg-blue-700; }
    &.danger { @apply bg-red-600 hover:bg-red-700; }
    &.secondary { @apply bg-gray-600 hover:bg-gray-700; }
  }
}

// Workflow timeline
.workflow-timeline {
  .timeline-item {
    &.completed .icon { @apply text-green-600; }
    &.current .icon { @apply text-blue-600; }
    &.pending .icon { @apply text-gray-400; }
  }
}
```

### Dark Mode Support

All workflow components automatically support Avo's dark mode.

## Performance Optimization

### Eager Loading

```ruby
class DocumentResource < Avo::BaseResource
  # Optimize workflow queries
  includes :workflow_execution, :workflow_steps, :workflow_history
  
  # Custom scopes for performance
  scope :with_active_workflows, -> { joins(:workflow_execution).where(workflow_executions: { status: 'active' }) }
  scope :pending_approval, -> { joins(:workflow_execution).where(workflow_executions: { current_step: 'under_review' }) }
end
```

### Caching

```ruby
# Enable caching for workflow data
field :workflow_status, as: :workflow_progress do |field|
  field.cache_duration = 5.minutes
  field.cache_key = :workflow_status_cache_key
end

private

def workflow_status_cache_key
  "workflow_status_#{record.id}_#{record.workflow_execution&.updated_at&.to_i}"
end
```

## Troubleshooting

### Common Issues

**1. Actions Not Showing**
```ruby
# Check permissions and action availability
def debug_workflow_actions
  execution = record.workflow_execution
  return "No workflow execution" unless execution
  
  {
    current_step: execution.current_step,
    available_actions: execution.available_actions,
    user_permissions: execution.available_actions_for_user(current_user),
    workflow_valid: execution.valid?
  }
end
```

**2. Performance Issues**
```ruby
# Add database indexes
class AddWorkflowIndexes < ActiveRecord::Migration[7.0]
  def change
    add_index :avo_workflow_executions, [:workflowable_type, :workflowable_id]
    add_index :avo_workflow_executions, :current_step
    add_index :avo_workflow_executions, :status
    add_index :avo_workflow_executions, :assigned_user_id
  end
end
```

**3. Context Data Issues**
```ruby
# Validate context data structure
def validate_workflow_context
  execution = record.workflow_execution
  context = execution.context_data
  
  # Check for common issues
  issues = []
  issues << "Context too large" if context.to_json.bytesize > 1.megabyte
  issues << "Invalid JSON structure" unless context.is_a?(Hash)
  issues << "Missing required keys" unless required_context_keys.all? { |key| context.key?(key) }
  
  issues
end
```

## Examples and Recipes

### Complete Document Management System

```ruby
# Complete example showing all integration features
class DocumentResource < Avo::BaseResource
  include Avo::Workflows::ResourceMethods
  
  # Basic fields
  field :title, as: :text, required: true
  field :content, as: :trix, hide_on: :index
  field :author, as: :belongs_to
  field :created_at, as: :date_time, readonly: true
  
  # Workflow fields
  field :workflow_status, as: :workflow_progress, 
        name: "Approval Status",
        show_on: [:show, :index]
  field :workflow_actions, as: :workflow_actions,
        show_on: :show,
        confirm_dangerous: true
  
  # Workflow panels
  panel :workflow_details, as: :workflow_step_panel do |panel|
    panel.name = "Current Workflow Status"
    panel.show_assigned_users = true
    panel.show_estimated_completion = true
  end
  
  panel :workflow_history, as: :workflow_history_panel, show_on: :show
  panel :workflow_context, as: :workflow_context_panel do |panel|
    panel.editable_fields = [:priority, :notes]
    panel.show_on = :show
  end
  
  # Filters
  filter :workflow_type, as: :workflow_class_filter
  filter :current_step, as: :current_step_filter
  filter :approval_status, as: :status_filter
  
  # Actions
  action :start_approval, as: :workflow_action
  action :assign_reviewer, as: :assign_workflow
  action :bulk_approve, as: :bulk_workflow_action
  
  # Scopes
  scope :pending_approval, -> { joins(:workflow_execution).where(workflow_executions: { current_step: 'under_review' }) }
  scope :approved, -> { joins(:workflow_execution).where(workflow_executions: { current_step: 'approved' }) }
end
```

This comprehensive integration provides a complete workflow management interface within Avo, giving users full control over workflow execution, monitoring, and administration.