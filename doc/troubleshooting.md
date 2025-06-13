# Troubleshooting Guide

## Common Issues

### Action Not Available Error

**Symptom**: `Avo::Workflows::Errors::ActionNotAvailableError`

**Causes**:
- Action conditions not met
- User permissions insufficient
- Workflow in wrong step

**Solutions**:
```ruby
# Check available actions
puts workflow.available_actions

# Check action conditions
action = workflow.class.find_action(:action_name)
puts action.conditions_met?(workflow)

# Debug step state
puts workflow.current_step
```

### Validation Errors

**Symptom**: `Avo::Workflows::Errors::ValidationError`

**Solutions**:
```ruby
# Check validation errors
begin
  workflow.perform_action(:action_name, user: user)
rescue Avo::Workflows::Errors::ValidationError => e
  puts e.validation_errors
end
```

### Performance Issues

**Symptoms**: Slow workflow execution, high memory usage

**Debugging**:
```ruby
# Enable performance monitoring
monitor = Avo::Workflows::Performance::Monitor.new(workflow)

monitor.monitor_operation('slow_operation') do
  # Your slow operation
end

# Get recommendations
recommendations = monitor.optimization_recommendations
recommendations.each { |rec| puts rec[:message] }
```

### Memory Leaks

**Solutions**:
```ruby
# Check memory usage
memory_optimizer = Avo::Workflows::Performance::Optimizations::MemoryOptimizer.new(workflow)
recommendations = memory_optimizer.generate_memory_recommendations

# Optimize memory
optimization_result = memory_optimizer.optimize_memory_usage
```

## Debugging Tools

### Workflow Debugger

```ruby
debugger = Avo::Workflows::Debugging::WorkflowDebugger.new(workflow)
debugger.enable_debug_mode

# Get detailed state information
state = debugger.inspect_state
puts state[:current_step_details]
```

### Performance Debugger

```ruby
perf_debugger = Avo::Workflows::Debugging::PerformanceDebugger.new(workflow)
bottlenecks = perf_debugger.identify_bottlenecks
```

## Recovery Procedures

### Rollback Failed Operations

```ruby
recovery = Avo::Workflows::Recovery::RecoveryManager.new(workflow)

# List recovery points
points = recovery.list_recovery_points

# Rollback to specific point
recovery.rollback_to_recovery_point(points.last[:id])
```

### Emergency Recovery

```ruby
# Force reset to safe state
emergency_recovery = Avo::Workflows::Recovery::EmergencyRecovery.new(workflow)
emergency_recovery.reset_to_initial_state
```
