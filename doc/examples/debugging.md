# Debugging Example

Debug workflow issues effectively.

## Enable Debug Mode

```ruby
debugger = Avo::Workflows::Debugging::WorkflowDebugger.new(workflow_execution)
debugger.enable_debug_mode

# Perform operations with debugging
debugger.debug_action(:problematic_action, user: current_user)

# Get debug report
debug_report = debugger.generate_debug_report
puts debug_report[:summary]
```

## Step-by-Step Debugging

```ruby
debugger.start_step_by_step_debugging

# Step through each operation
debugger.step_into_action(:next_action, user: current_user)
debugger.inspect_state
debugger.continue_execution
```

## Performance Debugging

```ruby
performance_debugger = Avo::Workflows::Debugging::PerformanceDebugger.new(workflow_execution)
bottlenecks = performance_debugger.identify_bottlenecks

bottlenecks.each do |bottleneck|
  puts "Bottleneck: #{bottleneck[:operation]} took #{bottleneck[:duration]}ms"
end
```
