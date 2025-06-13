# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Avo::Workflows::Debugging::WorkflowDebugger do
  let(:hr_user) { User.create!(name: 'HR Manager', email: 'hr@company.com') }
  let(:manager) { User.create!(name: 'Manager', email: 'manager@company.com') }
  
  let(:employee) do
    Employee.create!(
      name: 'John Doe',
      email: 'john.doe@company.com',
      employee_type: 'full_time',
      department: 'Engineering',
      salary_level: 'senior',
      start_date: Date.current + 1.week,
      manager: manager,
      hr_representative: hr_user
    )
  end

  let(:workflow_execution) { employee.start_onboarding!(assigned_to: hr_user) }
  let(:debugger) { described_class.new(workflow_execution) }

  describe '#initialize' do
    it 'sets workflow_execution and logger' do
      expect(debugger.workflow_execution).to eq(workflow_execution)
      expect(debugger.logger).to be_present
    end

    it 'accepts custom logger' do
      custom_logger = double('Logger')
      debugger = described_class.new(workflow_execution, logger: custom_logger)
      expect(debugger.logger).to eq(custom_logger)
    end
  end

  describe '#debug_report' do
    it 'returns comprehensive debug information' do
      report = debugger.debug_report

      expect(report).to include(
        :execution_summary,
        :current_state,
        :available_actions,
        :context_analysis,
        :validation_status,
        :history_analysis,
        :performance_metrics,
        :potential_issues
      )
    end

    it 'includes execution summary details' do
      report = debugger.debug_report
      summary = report[:execution_summary]

      expect(summary).to include(
        id: workflow_execution.id,
        workflow_class: 'EmployeeOnboardingWorkflow',
        current_step: 'initial_setup',
        status: 'active'
      )
    end

    it 'includes current state analysis' do
      report = debugger.debug_report
      state = report[:current_state]

      expect(state).to include(
        step_name: :initial_setup,
        is_final_step: false
      )
      expect(state[:available_actions]).to be >= 0
    end

    it 'analyzes context data' do
      report = debugger.debug_report
      analysis = report[:context_analysis]

      expect(analysis).to include(
        :total_keys,
        :nested_levels,
        :data_types,
        :size_estimate
      )
    end
  end

  describe '#validate_state' do
    it 'returns empty array for valid state' do
      issues = debugger.validate_state
      expect(issues).to be_an(Array)
    end

    it 'detects invalid current step' do
      workflow_execution.update_column(:current_step, 'invalid_step')
      issues = debugger.validate_state

      expect(issues).to include(match(/Current step 'invalid_step' not defined/))
    end
  end

  describe '#execution_trace' do
    it 'returns empty array for new execution' do
      trace = debugger.execution_trace
      expect(trace).to eq([])
    end

    it 'returns trace after transitions' do
      workflow_execution.perform_action(:begin_documentation_review, user: hr_user)
      
      trace = debugger.execution_trace
      expect(trace).not_to be_empty
      
      step = trace.first
      expect(step).to include(
        :step_number,
        :from_step,
        :to_step,
        :action,
        :timestamp
      )
    end
  end

  describe '#suggest_next_actions' do
    it 'suggests available actions with validation details' do
      suggestions = debugger.suggest_next_actions

      expect(suggestions).to be_an(Array)
      expect(suggestions).not_to be_empty

      action = suggestions.first
      expect(action).to include(
        :action,
        :target_step,
        :condition_met,
        :condition_details
      )
    end
  end

  describe '#simulate_action' do
    let(:available_action) { workflow_execution.available_actions.first }

    it 'simulates action without executing' do
      result = debugger.simulate_action(available_action)

      expect(result).to include(
        action: available_action,
        would_succeed: be_in([true, false])
      )

      # Verify workflow wasn't actually changed
      expect(workflow_execution.current_step).to eq('initial_setup')
    end

    it 'returns error for unavailable action' do
      result = debugger.simulate_action(:invalid_action)

      expect(result).to include(error: "Action not available")
    end

    it 'accepts test context for simulation' do
      test_context = { test_key: 'test_value' }
      result = debugger.simulate_action(available_action, test_context: test_context)

      expect(result).to include(:action, :would_succeed)
    end
  end

  describe '#analyze_workflow_graph' do
    it 'analyzes workflow structure' do
      analysis = debugger.analyze_workflow_graph

      expect(analysis).to include(
        :reachable_steps,
        :unreachable_steps,
        :potential_deadlocks,
        :cycle_detection,
        :final_states
      )
    end

    it 'identifies reachable steps from current position' do
      analysis = debugger.analyze_workflow_graph
      
      expect(analysis[:reachable_steps]).to include(:initial_setup)
      expect(analysis[:final_states]).to include(:completed, :terminated)
    end
  end

  describe '#performance_report' do
    it 'returns message for executions without history' do
      report = debugger.performance_report
      expect(report).to include(message: "No execution history available")
    end

    it 'analyzes performance with execution history' do
      # Create some history
      workflow_execution.perform_action(:begin_documentation_review, user: hr_user)
      
      report = debugger.performance_report
      expect(report).to include(:total_execution_time)
    end
  end

  describe '#export_debug_data' do
    it 'exports data in JSON format by default' do
      data = debugger.export_debug_data
      
      expect { JSON.parse(data) }.not_to raise_error
      parsed = JSON.parse(data)
      expect(parsed).to include('debug_report', 'exported_at')
    end

    it 'exports data in YAML format' do
      data = debugger.export_debug_data(format: :yaml)
      
      expect { YAML.safe_load(data, permitted_classes: [Time, Symbol], aliases: true) }.not_to raise_error
      parsed = YAML.safe_load(data, permitted_classes: [Time, Symbol], aliases: true)
      expect(parsed.keys.map(&:to_s)).to include('debug_report', 'exported_at')
    end

    it 'returns raw hash for other formats' do
      data = debugger.export_debug_data(format: :hash)
      
      expect(data).to be_a(Hash)
      expect(data).to include(:debug_report, :exported_at)
    end
  end
end

RSpec.describe Avo::Workflows::Debugging do
  let(:workflow_execution) { 
    double('WorkflowExecution', 
           id: 1, 
           current_step: 'test_step',
           workflow_definition: double('WorkflowDefinition'))
  }

  describe '.debug' do
    it 'creates a WorkflowDebugger instance' do
      debugger = described_class.debug(workflow_execution)
      expect(debugger).to be_a(Avo::Workflows::Debugging::WorkflowDebugger)
      expect(debugger.workflow_execution).to eq(workflow_execution)
    end
  end

  describe '.validate' do
    it 'validates workflow state' do
      allow_any_instance_of(Avo::Workflows::Debugging::WorkflowDebugger)
        .to receive(:validate_state).and_return([])

      result = described_class.validate(workflow_execution)
      expect(result).to eq([])
    end
  end

  describe '.trace' do
    it 'gets execution trace' do
      allow_any_instance_of(Avo::Workflows::Debugging::WorkflowDebugger)
        .to receive(:execution_trace).and_return([])

      result = described_class.trace(workflow_execution)
      expect(result).to eq([])
    end
  end

  describe '.export' do
    it 'exports debug data' do
      allow_any_instance_of(Avo::Workflows::Debugging::WorkflowDebugger)
        .to receive(:export_debug_data).with(format: :json).and_return('{}')

      result = described_class.export(workflow_execution, format: :json)
      expect(result).to eq('{}')
    end
  end
end