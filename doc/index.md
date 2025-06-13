# Avo Workflows Documentation

Welcome to the comprehensive documentation for Avo Workflows.

## Quick Start

### Installation

```bash
# Add to Gemfile
gem 'avo-workflows'

# Install and setup
bundle install
rails generate avo_workflows:install
rails db:migrate
```

### Basic Usage

```ruby
# 1. Define a workflow
class DocumentApprovalWorkflow < Avo::Workflows::Base
  step :draft do
    action :submit_for_review, to: :under_review
  end
  
  step :under_review do
    action :approve, to: :approved
    action :reject, to: :draft
  end
  
  step :approved
end

# 2. Add to your model
class Document < ApplicationRecord
  include Avo::Workflows::WorkflowMethods
end

# 3. Start and use workflow
document = Document.create!(title: "My Document")
workflow = document.start_workflow!(DocumentApprovalWorkflow, user: current_user)
workflow.perform_action(:submit_for_review, user: current_user)
workflow.perform_action(:approve, user: manager)
```

### Avo Integration

```ruby
# Add to your Avo resource
class DocumentResource < Avo::BaseResource
  include Avo::Workflows::ResourceMethods
  
  field :workflow_status, as: :workflow_progress
  field :workflow_actions, as: :workflow_actions
  panel :workflow_details, as: :workflow_step_panel
end
```

## Documentation Sections

### [API Documentation](api/index.html)
Complete API reference with detailed method documentation.

### [Workflow Documentation](workflows/index.html)
Detailed documentation for all available workflows.

### [Usage Examples](examples/index.html)
Practical examples and tutorials for common use cases.

### [Example Workflows Guide](examples/example_workflows.html)
Complete guide to the 5 production-ready example workflows included.

### [Avo Integration Guide](avo_integration.html)
Comprehensive guide to integrating workflows with Avo admin interface.

### [Performance Guide](performance.html)
Monitoring, benchmarking, and optimization documentation.

### [Troubleshooting](troubleshooting.html)
Common issues and debugging procedures.

## Generation Statistics

- **Modules Documented**: 
- **Classes Documented**: 
- **Methods Documented**: 
- **Workflows Documented**: 0
- **Examples Generated**: 5

Generated on: 2025-06-13 at 13:52:13
