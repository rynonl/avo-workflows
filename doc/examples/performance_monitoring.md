# Performance Monitoring Example

Monitor and optimize workflow performance.

## Basic Performance Monitoring

```ruby
# Create a performance monitor
monitor = Avo::Workflows::Performance::Monitor.new(workflow_execution)

# Monitor an operation
result = monitor.monitor_operation('document_processing') do
  workflow_execution.perform_action(:process_document, user: current_user)
end

# Get performance report
report = monitor.performance_report
puts "Operation took: #{report[:timing_analysis][:total_execution_time]}ms"
puts "Memory used: #{report[:memory_analysis][:memory_growth]}MB"
```

## Benchmarking

```ruby
benchmark = Avo::Workflows::Performance::Benchmark.new

# Compare different approaches
results = benchmark.compare(['approach_a', 'approach_b']) do |approach|
  case approach
  when 'approach_a'
    # Implementation A
  when 'approach_b'  
    # Implementation B
  end
end

puts "Fastest approach: #{results[:summary][:fastest]}"
```

## Optimization

```ruby
optimizer = Avo::Workflows::Performance::Optimizations::PerformanceOptimizer.new(workflow_execution)
optimization_result = optimizer.optimize_performance

puts "Optimization saved #{optimization_result[:memory_optimization][:memory_saved]}MB"
```
