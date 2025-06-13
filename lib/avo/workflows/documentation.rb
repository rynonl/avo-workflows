# frozen_string_literal: true

module Avo
  module Workflows
    # API Documentation and YARD docs generation utilities
    #
    # Provides tools for generating comprehensive documentation for workflow systems,
    # including API documentation, usage examples, and interactive documentation.
    #
    # @example Basic usage
    #   generator = Avo::Workflows::Documentation::Generator.new
    #   generator.generate_all_docs
    #
    # @example Generate specific documentation
    #   generator.generate_api_docs
    #   generator.generate_workflow_docs
    #   generator.generate_usage_examples
    #
    module Documentation
      # Main documentation generator
      class Generator
        attr_reader :output_dir, :options

        # Initialize documentation generator
        #
        # @param output_dir [String] directory for generated documentation
        # @param options [Hash] generation options
        # @option options [Boolean] :include_private (false) include private methods
        # @option options [Boolean] :include_examples (true) include code examples
        # @option options [String] :template ('default') documentation template
        def initialize(output_dir: 'doc', **options)
          @output_dir = output_dir
          @options = {
            include_private: false,
            include_examples: true,
            template: 'default',
            format: 'html'
          }.merge(options)
        end

        # Generate all documentation
        #
        # @return [Hash] generation results
        def generate_all_docs
          results = {}
          
          results[:api_docs] = generate_api_docs
          results[:workflow_docs] = generate_workflow_docs
          results[:usage_examples] = generate_usage_examples
          results[:performance_docs] = generate_performance_docs
          results[:troubleshooting] = generate_troubleshooting_guide
          
          # Generate index page
          results[:index] = generate_index_page(results)
          
          results
        end

        # Generate API documentation using YARD
        #
        # @return [Hash] API documentation results
        def generate_api_docs
          require 'yard'
          
          YARD::Registry.clear
          
          # Load all workflow files
          files = Dir.glob('lib/avo/workflows/**/*.rb')
          YARD.parse(files)
          
          # Generate documentation
          YARD::CLI::Yardoc.run('--output-dir', File.join(output_dir, 'api'))
          
          {
            status: :success,
            files_processed: files.size,
            output_path: File.join(output_dir, 'api'),
            modules_documented: count_documented_modules,
            classes_documented: count_documented_classes,
            methods_documented: count_documented_methods
          }
        rescue LoadError
          {
            status: :error,
            message: 'YARD gem not available. Install with: gem install yard'
          }
        rescue => e
          {
            status: :error,
            message: e.message
          }
        end

        # Generate workflow-specific documentation
        #
        # @return [Hash] workflow documentation results
        def generate_workflow_docs
          workflows = discover_workflows
          docs = {}
          
          workflows.each do |workflow_class|
            docs[workflow_class.name] = document_workflow_class(workflow_class)
          end
          
          # Write workflow documentation index
          write_workflow_index(docs)
          
          {
            status: :success,
            workflows_documented: workflows.size,
            output_path: File.join(output_dir, 'workflows'),
            workflow_docs: docs
          }
        end

        # Generate usage examples and tutorials
        #
        # @return [Hash] examples generation results
        def generate_usage_examples
          examples = {
            basic_workflow: generate_basic_workflow_example,
            advanced_workflow: generate_advanced_workflow_example,
            performance_monitoring: generate_performance_example,
            error_handling: generate_error_handling_example,
            debugging: generate_debugging_example
          }
          
          write_examples_index(examples)
          
          {
            status: :success,
            examples_generated: examples.size,
            output_path: File.join(output_dir, 'examples'),
            examples: examples.keys
          }
        end

        # Generate performance documentation
        #
        # @return [Hash] performance docs results
        def generate_performance_docs
          content = build_performance_documentation
          write_file(File.join(output_dir, 'performance.md'), content)
          
          {
            status: :success,
            output_path: File.join(output_dir, 'performance.md'),
            sections: %w[monitoring benchmarking optimization load_testing]
          }
        end

        # Generate troubleshooting guide
        #
        # @return [Hash] troubleshooting guide results
        def generate_troubleshooting_guide
          content = build_troubleshooting_guide
          write_file(File.join(output_dir, 'troubleshooting.md'), content)
          
          {
            status: :success,
            output_path: File.join(output_dir, 'troubleshooting.md'),
            sections: %w[common_issues debugging error_recovery performance_issues]
          }
        end

        private

        def generate_index_page(results)
          content = build_index_content(results)
          write_file(File.join(output_dir, 'index.md'), content)
          
          {
            status: :success,
            output_path: File.join(output_dir, 'index.md')
          }
        end

        def discover_workflows
          workflows = []
          
          # Load workflow files safely - prioritize examples
          safe_require_files('examples/workflows/**/*.rb')
          safe_require_files('examples/models/**/*.rb') 
          safe_require_files('lib/avo/workflows/**/*.rb')
          safe_require_files('app/avo/workflows/**/*.rb')
          
          # Find workflow classes
          ObjectSpace.each_object(Class) do |klass|
            if defined?(Avo::Workflows::Base) && klass < Avo::Workflows::Base && klass != Avo::Workflows::Base
              workflows << klass
            end
          end
          
          # Add example workflows manually if not found via ObjectSpace
          example_workflows = [
            'BlogPostWorkflow',
            'EmployeeOnboardingWorkflow', 
            'DocumentApprovalWorkflow',
            'IssueTrackingWorkflow',
            'OrderFulfillmentWorkflow'
          ]
          
          example_workflows.each do |workflow_name|
            begin
              workflow_class = Object.const_get(workflow_name)
              workflows << workflow_class unless workflows.include?(workflow_class)
            rescue NameError
              # Workflow class not loaded, skip
            end
          end
          
          workflows
        rescue => e
          puts "Warning: Could not discover all workflows: #{e.message}"
          []
        end

        def safe_require_files(pattern)
          Dir.glob(pattern).each do |file|
            require file
          rescue LoadError => e
            # Skip files that can't be loaded (e.g., missing dependencies)
            next
          end
        end

        def document_workflow_class(workflow_class)
          {
            name: workflow_class.name,
            description: extract_class_description(workflow_class),
            steps: document_workflow_steps(workflow_class),
            actions: document_workflow_actions(workflow_class),
            validations: document_workflow_validations(workflow_class),
            usage_example: generate_workflow_usage_example(workflow_class),
            file_path: workflow_class.method(:new).source_location&.first
          }
        end

        def document_workflow_steps(workflow_class)
          return [] unless workflow_class.respond_to?(:step_names)
          
          workflow_class.step_names.map do |step_name|
            step = workflow_class.find_step(step_name)
            {
              name: step_name,
              type: step&.class&.name || 'Step',
              description: extract_step_description(step),
              actions: step&.actions || [],
              validations: step&.validations || []
            }
          end
        end

        def document_workflow_actions(workflow_class)
          return [] unless workflow_class.respond_to?(:action_names)
          
          workflow_class.action_names.map do |action_name|
            action = workflow_class.find_action(action_name)
            {
              name: action_name,
              type: action&.class&.name || 'Action',
              description: extract_action_description(action),
              conditions: action&.conditions || [],
              effects: action&.effects || []
            }
          end
        end

        def document_workflow_validations(workflow_class)
          return [] unless workflow_class.respond_to?(:validations)
          
          workflow_class.validations.map do |validation|
            {
              type: validation.class.name,
              description: extract_validation_description(validation),
              conditions: validation.respond_to?(:conditions) ? validation.conditions : []
            }
          end
        end

        def generate_workflow_usage_example(workflow_class)
          <<~RUBY
            # Create a new workflow execution
            execution = #{workflow_class.name}.new(workflowable: your_model)
            
            # Check available actions
            available_actions = execution.available_actions
            # => [:action_name_1, :action_name_2, ...]
            
            # Perform an action
            result = execution.perform_action(:action_name, user: current_user)
            
            # Check current step
            current_step = execution.current_step
            # => "step_name"
            
            # Get workflow context
            context = execution.context_data
            # => { ... }
          RUBY
        end

        def extract_class_description(klass)
          if klass.respond_to?(:yard_description)
            klass.yard_description
          else
            "#{klass.name} workflow implementation"
          end
        end

        def extract_step_description(step)
          step&.respond_to?(:description) ? step.description : 'Workflow step'
        end

        def extract_action_description(action)
          action&.respond_to?(:description) ? action.description : 'Workflow action'
        end

        def extract_validation_description(validation)
          validation&.respond_to?(:description) ? validation.description : 'Workflow validation'
        end

        def generate_basic_workflow_example
          <<~MARKDOWN
            # Basic Workflow Example
            
            This example demonstrates creating and using a simple workflow.
            
            ## 1. Define the Workflow
            
            ```ruby
            class SimpleApprovalWorkflow < Avo::Workflows::Base
              step :draft do
                action :submit_for_review, to: :under_review
              end
              
              step :under_review do
                action :approve, to: :approved
                action :reject, to: :draft
              end
              
              step :approved
            end
            ```
            
            ## 2. Use the Workflow
            
            ```ruby
            # Attach to a model
            document = Document.create!(title: "Important Document")
            workflow = document.start_workflow!(SimpleApprovalWorkflow, user: current_user)
            
            # Perform actions
            workflow.perform_action(:submit_for_review, user: current_user)
            workflow.perform_action(:approve, user: manager)
            
            # Check status
            puts workflow.current_step  # => "approved"
            ```
          MARKDOWN
        end

        def generate_advanced_workflow_example
          <<~MARKDOWN
            # Advanced Workflow Example
            
            This example shows advanced workflow features including validations,
            conditions, and custom logic.
            
            ## Complex Workflow Definition
            
            ```ruby
            class AdvancedDocumentWorkflow < Avo::Workflows::Base
              step :draft do
                validate :content_present
                validate :author_assigned
                
                action :submit_for_review, to: :under_review do
                  condition { |execution| execution.workflowable.content.present? }
                  effect { |execution| execution.workflowable.update!(submitted_at: Time.current) }
                end
              end
              
              step :under_review do
                action :approve, to: :approved do
                  condition { |execution| execution.context[:reviewer_role] == 'manager' }
                  effect { |execution| NotificationService.send_approval(execution.workflowable) }
                end
                
                action :request_changes, to: :needs_revision do
                  effect { |execution| 
                    execution.update_context!(
                      feedback: execution.context[:review_comments],
                      revision_requested_at: Time.current
                    )
                  }
                end
              end
              
              step :needs_revision do
                action :resubmit, to: :under_review do
                  condition { |execution| execution.workflowable.updated_at > execution.context[:revision_requested_at] }
                end
              end
              
              step :approved
              
              private
              
              def content_present
                errors.add(:base, "Content is required") if workflowable.content.blank?
              end
              
              def author_assigned
                errors.add(:base, "Author must be assigned") if workflowable.author.blank?
              end
            end
            ```
          MARKDOWN
        end

        def generate_performance_example
          <<~MARKDOWN
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
            puts "Operation took: \#{report[:timing_analysis][:total_execution_time]}ms"
            puts "Memory used: \#{report[:memory_analysis][:memory_growth]}MB"
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
            
            puts "Fastest approach: \#{results[:summary][:fastest]}"
            ```
            
            ## Optimization
            
            ```ruby
            optimizer = Avo::Workflows::Performance::Optimizations::PerformanceOptimizer.new(workflow_execution)
            optimization_result = optimizer.optimize_performance
            
            puts "Optimization saved \#{optimization_result[:memory_optimization][:memory_saved]}MB"
            ```
          MARKDOWN
        end

        def generate_error_handling_example
          <<~MARKDOWN
            # Error Handling Example
            
            Handle errors gracefully in workflows.
            
            ## Error Handling Setup
            
            ```ruby
            begin
              workflow_execution.perform_action(:risky_action, user: current_user)
            rescue Avo::Workflows::Errors::ActionNotAvailableError => e
              puts "Action not available: \#{e.message}"
            rescue Avo::Workflows::Errors::ValidationError => e
              puts "Validation failed: \#{e.validation_errors}"
            rescue Avo::Workflows::Errors::WorkflowError => e
              puts "Workflow error: \#{e.message}"
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
          MARKDOWN
        end

        def generate_debugging_example
          <<~MARKDOWN
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
              puts "Bottleneck: \#{bottleneck[:operation]} took \#{bottleneck[:duration]}ms"
            end
            ```
          MARKDOWN
        end

        def build_performance_documentation
          <<~MARKDOWN
            # Performance Documentation
            
            ## Overview
            
            The Avo Workflows performance system provides comprehensive monitoring,
            benchmarking, and optimization capabilities for workflow executions.
            
            ## Performance Monitoring
            
            ### Basic Monitoring
            
            ```ruby
            monitor = Avo::Workflows::Performance::Monitor.new(workflow_execution)
            
            # Monitor single operation
            monitor.monitor_operation('operation_name') do
              # Your operation code
            end
            
            # Get comprehensive report
            report = monitor.performance_report
            ```
            
            ### Available Metrics
            
            - **Execution Time**: Total and per-operation timing
            - **Memory Usage**: Current, peak, and growth tracking  
            - **Database Queries**: Query count and optimization opportunities
            - **Bottleneck Analysis**: Identify slow operations
            
            ## Benchmarking
            
            ### Operation Comparison
            
            ```ruby
            benchmark = Avo::Workflows::Performance::Benchmark.new
            
            results = benchmark.compare(['implementation_a', 'implementation_b']) do |impl|
              # Test each implementation
            end
            ```
            
            ### Load Testing
            
            ```ruby
            load_results = benchmark.load_test(
              WorkflowClass,
              concurrent_executions: 10,
              operations_per_execution: 5
            )
            
            puts "Throughput: \#{load_results[:throughput]} workflows/second"
            ```
            
            ## Optimization
            
            ### Automatic Optimization
            
            ```ruby
            optimizer = Avo::Workflows::Performance::Optimizations::PerformanceOptimizer.new(workflow_execution)
            results = optimizer.optimize_performance
            
            # Or auto-optimize based on current metrics
            auto_results = optimizer.auto_optimize
            ```
            
            ### Query Optimization
            
            ```ruby
            query_optimizer = Avo::Workflows::Performance::Optimizations::QueryOptimizer.new(workflow_execution)
            
            # Enable optimizations
            query_optimizer.enable_eager_loading([:workflowable, :user])
            query_optimizer.enable_caching([:workflow_definition, :step_definitions])
            
            # Get optimization recommendations
            report = query_optimizer.optimization_report
            ```
            
            ### Memory Optimization
            
            ```ruby
            memory_optimizer = Avo::Workflows::Performance::Optimizations::MemoryOptimizer.new(workflow_execution)
            
            # Optimize memory usage
            optimization_result = memory_optimizer.optimize_memory_usage
            
            # Get memory recommendations
            recommendations = memory_optimizer.generate_memory_recommendations
            ```
            
            ## Performance Best Practices
            
            1. **Monitor Regularly**: Set up monitoring for production workflows
            2. **Optimize Context Size**: Keep workflow context data manageable
            3. **Use Caching**: Enable caching for frequently accessed data
            4. **Batch Operations**: Group related operations together
            5. **Profile Regularly**: Use benchmarking to catch regressions
          MARKDOWN
        end

        def build_troubleshooting_guide
          <<~MARKDOWN
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
          MARKDOWN
        end

        def build_index_content(results)
          <<~MARKDOWN
            # Avo Workflows Documentation
            
            Welcome to the comprehensive documentation for Avo Workflows.
            
            ## Quick Start
            
            ```ruby
            # Define a workflow
            class MyWorkflow < Avo::Workflows::Base
              step :initial do
                action :start, to: :active
              end
              
              step :active do
                action :complete, to: :finished
              end
              
              step :finished
            end
            
            # Use the workflow
            execution = MyWorkflow.create!(workflowable: my_model, user: current_user)
            execution.perform_action(:start, user: current_user)
            ```
            
            ## Documentation Sections
            
            ### [API Documentation](api/index.html)
            Complete API reference with detailed method documentation.
            
            ### [Workflow Documentation](workflows/index.html)
            Detailed documentation for all available workflows.
            
            ### [Usage Examples](examples/index.html)
            Practical examples and tutorials for common use cases.
            
            ### [Performance Guide](performance.html)
            Monitoring, benchmarking, and optimization documentation.
            
            ### [Troubleshooting](troubleshooting.html)
            Common issues and debugging procedures.
            
            ## Generation Statistics
            
            - **Modules Documented**: #{results[:api_docs][:modules_documented] if results[:api_docs][:status] == :success}
            - **Classes Documented**: #{results[:api_docs][:classes_documented] if results[:api_docs][:status] == :success}
            - **Methods Documented**: #{results[:api_docs][:methods_documented] if results[:api_docs][:status] == :success}
            - **Workflows Documented**: #{results[:workflow_docs][:workflows_documented] if results[:workflow_docs][:status] == :success}
            - **Examples Generated**: #{results[:usage_examples][:examples_generated] if results[:usage_examples][:status] == :success}
            
            Generated on: #{Time.current.strftime('%Y-%m-%d at %H:%M:%S')}
          MARKDOWN
        end

        def write_workflow_index(docs)
          content = +<<~MARKDOWN
            # Workflow Documentation
            
            ## Available Workflows
            
          MARKDOWN
          
          docs.each do |workflow_name, doc|
            content << <<~MARKDOWN
              ### #{workflow_name}
              
              #{doc[:description]}
              
              **Steps**: #{doc[:steps].map { |s| "`#{s[:name]}`" }.join(', ')}
              **Actions**: #{doc[:actions].map { |a| "`#{a[:name]}`" }.join(', ')}
              
              [View Details](#{workflow_name.downcase.gsub('::', '_')}.html)
              
            MARKDOWN
          end
          
          write_file(File.join(output_dir, 'workflows', 'index.md'), content)
          
          # Write individual workflow documentation files
          docs.each do |workflow_name, doc|
            workflow_content = build_workflow_doc_content(workflow_name, doc)
            filename = "#{workflow_name.downcase.gsub('::', '_')}.md"
            write_file(File.join(output_dir, 'workflows', filename), workflow_content)
          end
        end

        def build_workflow_doc_content(workflow_name, doc)
          <<~MARKDOWN
            # #{workflow_name}
            
            #{doc[:description]}
            
            **File**: `#{doc[:file_path]}`
            
            ## Steps
            
            #{doc[:steps].map { |step| 
              "### #{step[:name]}\n\n#{step[:description]}\n\n**Actions**: #{step[:actions].join(', ')}\n"
            }.join("\n")}
            
            ## Actions
            
            #{doc[:actions].map { |action|
              "### #{action[:name]}\n\n#{action[:description]}\n"
            }.join("\n")}
            
            ## Usage Example
            
            ```ruby
            #{doc[:usage_example]}
            ```
          MARKDOWN
        end

        def write_examples_index(examples)
          content = +<<~MARKDOWN
            # Usage Examples
            
            ## Available Examples
            
          MARKDOWN
          
          examples.each do |name, _|
            content << "- [#{name.to_s.tr('_', ' ').split.map(&:capitalize).join(' ')}](#{name}.html)\n"
          end
          
          write_file(File.join(output_dir, 'examples', 'index.md'), content)
          
          # Write individual example files
          examples.each do |name, content|
            write_file(File.join(output_dir, 'examples', "#{name}.md"), content)
          end
        end

        def count_documented_modules
          return 0 unless defined?(YARD)
          YARD::Registry.all(:module).size
        end

        def count_documented_classes
          return 0 unless defined?(YARD)
          YARD::Registry.all(:class).size
        end

        def count_documented_methods
          return 0 unless defined?(YARD)
          YARD::Registry.all(:method).size
        end

        def write_file(path, content)
          FileUtils.mkdir_p(File.dirname(path))
          File.write(path, content)
        end
      end

      # Interactive documentation server
      class Server
        def self.start(port: 3001, host: 'localhost')
          require 'webrick'
          
          doc_root = File.join(Dir.pwd, 'doc')
          
          server = WEBrick::HTTPServer.new(
            Port: port,
            DocumentRoot: doc_root,
            Host: host
          )
          
          puts "Starting documentation server at http://#{host}:#{port}"
          puts "Serving documentation from: #{doc_root}"
          
          trap('INT') { server.shutdown }
          server.start
        rescue LoadError
          puts "WEBrick not available. Install with: gem install webrick"
        end
      end

      # Command-line interface for documentation generation
      class CLI
        def self.run(args)
          case args.first
          when 'generate'
            generator = Generator.new
            results = generator.generate_all_docs
            puts "Documentation generated successfully!"
            puts "API docs: #{results[:api_docs][:output_path]}" if results[:api_docs][:status] == :success
            puts "Workflow docs: #{results[:workflow_docs][:output_path]}" if results[:workflow_docs][:status] == :success
          when 'serve'
            port = args[1]&.to_i || 3001
            Server.start(port: port)
          when 'clean'
            FileUtils.rm_rf('doc')
            puts "Documentation cleaned"
          else
            puts usage_message
          end
        end

        def self.usage_message
          <<~USAGE
            Avo Workflows Documentation Tool
            
            Usage:
              avo-workflows-docs generate  # Generate all documentation
              avo-workflows-docs serve     # Start documentation server
              avo-workflows-docs clean     # Clean generated documentation
            
            Options:
              serve [port]                 # Specify port (default: 3001)
          USAGE
        end
      end
    end
  end
end