# Error Handling Example

Handle errors gracefully in workflows.

## Error Handling Setup

```ruby
begin
  workflow_execution.perform_action(:risky_action, user: current_user)
rescue Avo::Workflows::Errors::ActionNotAvailableError => e
  puts "Action not available: #{e.message}"
rescue Avo::Workflows::Errors::ValidationError => e
  puts "Validation failed: #{e.validation_errors}"
rescue Avo::Workflows::Errors::WorkflowError => e
  puts "Workflow error: #{e.message}"
end
```

## Recovery Mechanisms

```ruby
recovery = Avo::Workflows::Recovery::RecoveryManager.new(workflow_execution)

# Create recovery point
recovery_point = recovery.create_recovery_point('before_risky_operation')

begin
  workflow_execution.perform_action(:risky_action, user: current_user)
rescue => e
  # Rollback to recovery point
  recovery.rollback_to_recovery_point(recovery_point[:id])
  puts "Rolled back to safe state"
end
```
