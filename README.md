# Avo Workflows

[![Gem Version](https://badge.fury.io/rb/avo-workflows.svg)](https://badge.fury.io/rb/avo-workflows)
[![Build Status](https://github.com/avo-hq/avo-workflows/workflows/CI/badge.svg)](https://github.com/avo-hq/avo-workflows/actions)

A powerful workflow engine that integrates seamlessly with Avo admin interface and Rails applications. Build sophisticated, multi-step workflows with conditional logic, validations, and comprehensive monitoring.

## Features

- 🚀 **Declarative Workflow Definition** - Define workflows using an intuitive Ruby DSL
- 🔄 **State Management** - Robust step-based state transitions with validation
- 🎛️ **Avo Integration** - Native integration with Avo admin interface (fields, panels, actions)
- 📝 **Rich Data Collection Forms** - Built-in form system for collecting workflow action data
- 👥 **Multi-User Support** - Assign workflows to users and track assignments
- 📊 **Performance Monitoring** - Built-in performance tracking and optimization
- 🔍 **Debugging Tools** - Comprehensive debugging and recovery mechanisms
- 🏗️ **Polymorphic Support** - Works with any Rails model via polymorphic associations
- ⚡ **Production Ready** - Enterprise-grade error handling and recovery

## Quick Start

### Installation

Add to your Gemfile:

```ruby
gem 'avo-workflows'
```

Run the installer:

```bash
bundle install
rails generate avo_workflows:install
rails db:migrate
```

### Basic Usage

**1. Define a Workflow**

```ruby
# app/avo/workflows/document_approval_workflow.rb
class DocumentApprovalWorkflow < Avo::Workflows::Base
  step :draft do
    action :submit_for_review, to: :under_review
  end
  
  step :under_review do
    action :approve, to: :approved do
      condition { |execution| execution.context[:reviewer_role] == 'manager' }
    end
    action :reject, to: :draft
  end
  
  step :approved
end
```

**2. Add to Your Model**

```ruby
# app/models/document.rb
class Document < ApplicationRecord
  include Avo::Workflows::WorkflowMethods
  
  has_many_attached :files
  validates :title, presence: true
end
```

**3. Start and Execute Workflows**

```ruby
# Create and start workflow
document = Document.create!(title: "Important Document")
workflow = document.start_workflow!(DocumentApprovalWorkflow, user: current_user)

# Check available actions
workflow.available_actions
# => [:submit_for_review]

# Perform actions
workflow.perform_action(:submit_for_review, user: current_user)
workflow.perform_action(:approve, user: manager, context: { reviewer_role: 'manager' })

# Check workflow state
workflow.current_step
# => "approved"
```

**4. Avo Integration with Forms**

```ruby
# Create workflow action forms for rich data collection
class ApprovalForm < Avo::Workflows::Forms::Base
  field :approval_comments, as: :textarea, required: true
  field :notify_stakeholders, as: :boolean, default: true
  field :priority_level, as: :select, options: ['low', 'medium', 'high']
end

# Register forms with workflow actions
class DocumentApprovalWorkflow < Avo::Workflows::Base
  action_form :approve, ApprovalForm
  # ... workflow definition
end

# Add to your Avo resource
class DocumentResource < Avo::BaseResource
  include Avo::Workflows::ResourceMethods
  
  field :title, as: :text
  field :workflow_status, as: :workflow_progress
  field :workflow_actions, as: :workflow_actions  # Automatically shows forms
  
  panel :workflow_details, as: :workflow_step_panel
  panel :workflow_history, as: :workflow_history_panel
end
```

## Example Workflows

### Employee Onboarding
Complete multi-step onboarding with document collection, IT setup, and training tracking.

```ruby
workflow = employee.start_onboarding!(assigned_to: hr_user)
workflow.perform_action(:collect_documents, user: hr_user)
workflow.perform_action(:setup_it_account, user: it_user)
# ... full example in examples/workflows/employee_onboarding_workflow.rb
```

### Blog Post Publishing
Editorial workflow with drafts, reviews, and publishing steps.

```ruby
workflow = blog_post.start_workflow!(BlogPostWorkflow, user: author)
workflow.perform_action(:submit_for_review, user: author)
workflow.perform_action(:publish, user: editor)
# ... full example in examples/workflows/blog_post_workflow.rb
```

### Document Approval
Multi-level approval workflow with role-based conditions.

```ruby
workflow = document.start_approval!(assigned_to: manager)
workflow.perform_action(:submit_for_review, user: author)
workflow.perform_action(:approve, user: manager)
# ... full example in examples/workflows/document_approval_workflow.rb
```

## Advanced Features

### Performance Monitoring

```ruby
# Monitor workflow performance
monitor = Avo::Workflows::Performance::Monitor.new(workflow_execution)
report = monitor.performance_report

# Benchmark different approaches
benchmark = Avo::Workflows::Performance::Benchmark.new
results = benchmark.load_test(WorkflowClass, concurrent_executions: 10)
```

### Error Handling & Recovery

```ruby
# Automatic recovery points
recovery = Avo::Workflows::Recovery::RecoveryManager.new(workflow)
recovery_point = recovery.create_recovery_point('before_critical_step')

# Rollback on failure
recovery.rollback_to_recovery_point(recovery_point[:id])
```

### Debugging Tools

```ruby
# Enable debug mode
debugger = Avo::Workflows::Debugging::WorkflowDebugger.new(workflow)
debugger.enable_debug_mode
debugger.debug_action(:problematic_action, user: current_user)
```

## Documentation

- **[Complete Documentation](doc/index.md)** - Comprehensive guides and API reference
- **[Quick Start Guide](doc/examples/basic_workflow.md)** - Get started in 10 minutes  
- **[Example Workflows Guide](doc/examples/example_workflows.md)** - Production-ready workflow examples
- **[Avo Integration Guide](doc/avo_integration.md)** - Complete Avo admin integration
- **[Workflow Forms Guide](doc/workflow_forms.md)** - Rich data collection forms for actions
- **[Performance Guide](doc/performance.md)** - Monitoring and optimization
- **[Troubleshooting](doc/troubleshooting.md)** - Common issues and solutions
- **[API Reference](doc/api/)** - Complete method documentation

Generate documentation locally:

```bash
bundle exec rake docs:generate
bundle exec rake docs:serve  # Serves at http://localhost:3001
```

## Configuration

```ruby
# config/initializers/avo_workflows.rb
Avo::Workflows.configure do |config|
  config.user_class = "User"
  config.enabled = true
  config.default_assignee = :creator
  config.performance_monitoring = true
  config.debug_mode = Rails.env.development?
end
```

## Requirements

- **Ruby** 3.0+
- **Rails** 7.0+  
- **Avo** 3.0+ (for Avo integration features)

## Development

```bash
git clone https://github.com/avo-hq/avo-workflows.git
cd avo-workflows
bundle install
bundle exec rspec
```

## Contributing

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Write tests for your changes
4. Ensure all tests pass (`bundle exec rspec`)
5. Commit your changes (`git commit -am 'Add amazing feature'`)
6. Push to the branch (`git push origin feature/amazing-feature`)
7. Open a Pull Request

## License

This gem is available as open source under the terms of the [MIT License](LICENSE.txt).

## Support

- **Documentation**: [Full documentation site](doc/index.md)
- **Examples**: See the [`examples/`](examples/) directory
- **Issues**: [GitHub Issues](https://github.com/avo-hq/avo-workflows/issues)
- **Discussions**: [GitHub Discussions](https://github.com/avo-hq/avo-workflows/discussions)