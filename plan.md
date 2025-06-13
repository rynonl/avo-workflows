# Avo Workflows Gem Development Plan

## Phase 1: Foundation & Setup with Testing (2-3 hours)
1. **Create Ruby gem structure** with proper gemspec, bundler setup, and Avo dependency
2. **Set up comprehensive test suite** (RSpec, test database, CI configuration)
3. **Create Rails generators** for workflow scaffolding (`rails g avo_workflows:install`)
4. **Establish database schema** with single migration for:
   - `avo_workflow_executions` table (polymorphic workflowable + configurable user model)
5. **Create configuration system** for user model and other app-specific settings
6. **Write tests** for generators, configuration, and database setup

## Phase 2: Core Workflow System with TDD (4-5 hours)
7. **Build Workflow DSL** - Ruby classes defining steps, actions, and transitions (test-driven)
8. **Create WorkflowExecution model** with state machine functionality (comprehensive model tests)
9. **Implement workflow execution engine** - step transitions, context management (integration tests)
10. **Add workflow discovery/registration** system for code-based workflow definitions (unit tests)
11. **Build step validation** and error handling (edge case testing)
12. **Create example workflows** for testing and demonstration

## Phase 3: Avo Integration with Testing (3-4 hours)
13. **Create WorkflowResource class** extending Avo::BaseResource (resource tests)
14. **Build dynamic panels** showing different UI based on current workflow step (UI tests)
15. **Create custom Avo fields** for workflow-specific data (field tests)
16. **Implement workflow action buttons** for step transitions within Avo (integration tests)
17. **Add workflow visualization** component showing progress (component tests)
18. **Test Avo integration** thoroughly with dummy Rails app

## Phase 4: Documentation & Polish (2-3 hours)
19. **Write comprehensive documentation** with usage examples and API reference
20. **Create advanced example workflows** demonstrating complex business patterns
21. **Add error handling/recovery** mechanisms and workflow debugging
22. **Performance testing** and optimization
23. **Final integration testing** with real-world scenarios

## AI Integration (Future Phase - Not Implemented Initially)
- LLM provider integration
- AI step types with prompt templates
- AI decision engines for automated transitions
- Human-in-the-loop patterns
- Context-aware AI workflows

## Key Technical Architecture
- **Code-based workflow definitions** (version controlled, testable)
- **Single database table** for execution tracking with polymorphic associations
- **Configurable user model** to work with any Rails app
- **Avo Resource integration** for seamless admin interface
- **Comprehensive testing** throughout development (TDD approach)
- **Context management** for data flow between steps
- **Rails generator** for easy setup and scaffolding

## Testing Strategy
- **Unit tests** for all core classes and methods
- **Integration tests** for workflow execution and state transitions
- **Avo integration tests** for UI components and resource functionality
- **Generator tests** for Rails scaffolding
- **End-to-end tests** with example workflows
- **Performance tests** for complex workflow scenarios

## Database Schema

### avo_workflow_executions
```ruby
create_table :avo_workflow_executions do |t|
  t.string :workflow_class, null: false           # "ApprovalWorkflow" 
  t.references :workflowable, polymorphic: true, null: false  # the record being processed
  t.string :current_step, null: false             # "pending_review"
  t.json :context_data                            # user inputs, intermediate data
  t.json :step_history                            # audit trail of transitions
  t.string :status, default: 'active'            # active, completed, failed, paused
  t.references :assigned_to, polymorphic: true, null: true    # configurable user model
  t.timestamps
end
```

## Configuration Pattern
```ruby
# config/initializers/avo_workflows.rb
AvoWorkflows.configure do |config|
  config.user_class = "User"  # or "Account", "Admin", etc.
end
```

## Example Workflow DSL
```ruby
# app/avo/workflows/approval_workflow.rb
class ApprovalWorkflow < AvoWorkflows::Base
  step :draft do
    action :submit_for_review, to: :pending_review
    action :save_draft, to: :draft
  end
  
  step :pending_review do
    action :approve, to: :approved
    action :reject, to: :rejected
    action :request_changes, to: :draft
  end
  
  step :approved do
    # terminal state
  end
end
```