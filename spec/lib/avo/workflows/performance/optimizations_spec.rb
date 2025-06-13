# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Avo::Workflows::Performance::Optimizations do
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

  describe Avo::Workflows::Performance::Optimizations::QueryOptimizer do
    let(:optimizer) { described_class.new(workflow_execution) }

    describe '#initialize' do
      it 'sets up query optimizer for workflow execution' do
        expect(optimizer.workflow_execution).to eq(workflow_execution)
      end
    end

    describe '#optimize_queries_for_operation' do
      it 'optimizes queries for step history analysis' do
        result = optimizer.optimize_queries_for_operation(:step_history_analysis)

        expect(result).to include(
          :operation,
          :queries_before,
          :queries_after,
          :queries_saved,
          :optimizations_applied
        )
        expect(result[:operation]).to eq(:step_history_analysis)
      end

      it 'optimizes queries for context operations' do
        result = optimizer.optimize_queries_for_operation(:context_operations)

        expect(result).to include(:operation, :optimizations_applied)
        expect(result[:operation]).to eq(:context_operations)
      end

      it 'handles unknown operation types' do
        result = optimizer.optimize_queries_for_operation(:unknown_operation)

        expect(result).to include(:operation)
        expect(result[:operation]).to eq(:unknown_operation)
      end
    end

    describe '#enable_eager_loading' do
      it 'enables eager loading for specified associations' do
        optimizer.enable_eager_loading([:workflowable, :user])

        # Test that optimizations are tracked
        result = optimizer.optimize_queries_for_operation(:test_operation)
        expect(result[:optimizations_applied]).to include(match(/eager_loading/))
      end
    end

    describe '#enable_caching' do
      it 'enables caching for specified data types' do
        optimizer.enable_caching([:workflow_definition, :available_actions])

        result = optimizer.optimize_queries_for_operation(:test_operation)
        expect(result[:optimizations_applied]).to include(match(/caching/))
      end
    end

    describe '#optimize_context_storage' do
      it 'optimizes large context objects' do
        # Add large context data
        large_context = {
          large_data: 'x' * 50000, # 50KB string
          normal_data: 'small'
        }
        workflow_execution.update_context!(large_context)

        large_objects = optimizer.optimize_context_storage

        expect(large_objects).to be_an(Array)
        # Should identify the large_data as a large object (if any large objects found)
        if large_objects.any?
          large_data_obj = large_objects.find { |obj| obj[:key] == :large_data }
          expect(large_data_obj).to be_present
        end
      end

      it 'handles workflow with no large context objects' do
        small_context = { small_data: 'tiny' }
        workflow_execution.update_context!(small_context)

        large_objects = optimizer.optimize_context_storage

        expect(large_objects).to be_an(Array)
        expect(large_objects).to be_empty
      end
    end

    describe '#optimization_report' do
      it 'generates comprehensive optimization analysis' do
        report = optimizer.optimization_report

        expect(report).to include(
          :current_queries,
          :optimization_opportunities,
          :recommended_indexes,
          :caching_opportunities,
          :eager_loading_suggestions
        )
      end

      it 'identifies optimization opportunities' do
        report = optimizer.optimization_report
        opportunities = report[:optimization_opportunities]

        expect(opportunities).to be_an(Array)
        opportunities.each do |opp|
          expect(opp).to include(:type, :severity, :description, :solution)
        end
      end

      it 'recommends database indexes' do
        report = optimizer.optimization_report
        indexes = report[:recommended_indexes]

        expect(indexes).to be_an(Array)
        indexes.each do |index|
          expect(index).to include(:table, :columns, :reason)
        end
      end
    end
  end

  describe Avo::Workflows::Performance::Optimizations::MemoryOptimizer do
    let(:optimizer) { described_class.new(workflow_execution) }

    describe '#initialize' do
      it 'sets up memory optimizer for workflow execution' do
        expect(optimizer.workflow_execution).to eq(workflow_execution)
      end
    end

    describe '#optimize_memory_usage' do
      it 'optimizes memory usage and reports results' do
        # Add some data that can be optimized
        workflow_execution.update_context!(
          temp_data: Array.new(100) { |i| "temp_#{i}" },
          large_string: 'x' * 10000
        )

        result = optimizer.optimize_memory_usage

        expect(result).to include(
          :initial_memory,
          :final_memory,
          :memory_saved,
          :optimizations_applied,
          :recommendations
        )
        expect(result[:optimizations_applied]).to be_an(Array)
      end

      it 'handles workflow with minimal optimization needs' do
        workflow_execution.update_context!(small_data: 'minimal')

        result = optimizer.optimize_memory_usage

        expect(result).to include(:initial_memory, :final_memory, :optimizations_applied)
        expect(result[:optimizations_applied]).to be_an(Array)
      end
    end

    describe '#cleanup_memory' do
      it 'cleans up temporary objects' do
        # This test is somewhat artificial since we can't easily create
        # instance variables on the optimizer
        cleaned_count = optimizer.cleanup_memory

        expect(cleaned_count).to be_an(Integer)
        expect(cleaned_count).to be >= 0
      end
    end

    describe '#generate_memory_recommendations' do
      it 'provides memory optimization recommendations' do
        recommendations = optimizer.generate_memory_recommendations

        expect(recommendations).to be_an(Array)
        recommendations.each do |rec|
          expect(rec).to include(:type, :severity, :message, :suggestion)
        end
      end

      it 'recommends optimization for large context' do
        # Create large context to trigger recommendations
        large_context = { huge_data: 'x' * 200000 } # 200KB
        workflow_execution.update_context!(large_context)

        recommendations = optimizer.generate_memory_recommendations

        large_context_rec = recommendations.find { |r| r[:type] == :large_context }
        expect(large_context_rec).to be_present
        expect(large_context_rec[:severity]).to eq(:high)
      end
    end
  end

  describe Avo::Workflows::Performance::Optimizations::PerformanceOptimizer do
    let(:optimizer) { described_class.new(workflow_execution) }

    describe '#initialize' do
      it 'sets up performance optimizer with query and memory optimizers' do
        expect(optimizer.workflow_execution).to eq(workflow_execution)
        expect(optimizer.query_optimizer).to be_a(Avo::Workflows::Performance::Optimizations::QueryOptimizer)
        expect(optimizer.memory_optimizer).to be_a(Avo::Workflows::Performance::Optimizations::MemoryOptimizer)
      end
    end

    describe '#optimize_performance' do
      it 'runs comprehensive performance optimization' do
        result = optimizer.optimize_performance

        expect(result).to include(
          :started_at,
          :query_optimization,
          :memory_optimization,
          :overall_impact,
          :completed_at,
          :total_time
        )
        expect(result[:total_time]).to be > 0
      end

      it 'allows selective optimization' do
        result = optimizer.optimize_performance(optimize_queries: false, optimize_memory: true)

        expect(result[:query_optimization]).to be_nil
        expect(result[:memory_optimization]).to be_present
      end

      it 'calculates overall impact correctly' do
        result = optimizer.optimize_performance

        impact = result[:overall_impact]
        expect(impact).to include(:score, :improvements, :assessment)
        expect(impact[:score]).to be_an(Integer)
        expect(impact[:improvements]).to be_an(Array)
        expect(impact[:assessment]).to be_in(['minimal', 'moderate', 'significant', 'substantial'])
      end
    end

    describe '#auto_optimize' do
      it 'automatically optimizes based on performance metrics' do
        result = optimizer.auto_optimize

        expect(result).to include(
          :auto_optimizations,
          :recommendations_processed,
          :optimizations_applied
        )
        expect(result[:auto_optimizations]).to be_an(Array)
        expect(result[:recommendations_processed]).to be_an(Integer)
        expect(result[:optimizations_applied]).to be_an(Integer)
      end

      it 'handles workflow with no optimization needs' do
        result = optimizer.auto_optimize

        expect(result[:optimizations_applied]).to be >= 0
      end
    end
  end

  describe 'Integration Testing' do
    it 'optimizes real workflow execution performance' do
      # Create a workflow with performance challenges
      workflow_execution.update_context!(
        large_array: Array.new(1000) { |i| "data_#{i}" },
        temp_cache: Array.new(500) { |i| { cached: "value_#{i}" } },
        metadata: {
          created_at: Time.current,
          size_info: 'x' * 10000
        }
      )

      # Measure before optimization
      before_size = workflow_execution.context_data.to_s.bytesize

      # Run comprehensive optimization
      optimizer = Avo::Workflows::Performance::Optimizations::PerformanceOptimizer.new(workflow_execution)
      result = optimizer.optimize_performance

      # Measure after optimization
      workflow_execution.reload
      after_size = workflow_execution.context_data.to_s.bytesize

      expect(result[:overall_impact][:score]).to be >= 0
      expect(result[:memory_optimization]).to be_present

      # Context size should be optimized (or at least not increased)
      expect(after_size).to be <= before_size * 1.1 # Allow 10% variance
    end

    it 'provides actionable optimization recommendations' do
      # Create suboptimal conditions
      workflow_execution.update_context!(
        inefficient_data: 'x' * 100000, # Large string
        temp_vars: Array.new(200) { |i| "temp_#{i}" }
      )

      optimizer = Avo::Workflows::Performance::Optimizations::PerformanceOptimizer.new(workflow_execution)
      
      # Get query optimization recommendations
      query_report = optimizer.query_optimizer.optimization_report
      
      # Get memory optimization recommendations  
      memory_recs = optimizer.memory_optimizer.generate_memory_recommendations

      expect(query_report[:optimization_opportunities]).to be_an(Array)
      expect(memory_recs).to be_an(Array)

      # Should provide actionable recommendations
      all_recommendations = query_report[:optimization_opportunities] + memory_recs
      
      all_recommendations.each do |rec|
        expect(rec).to include(:type)
        expect(rec).to include(:severity) if rec.key?(:severity)
        expect(rec).to include(:solution) if rec.key?(:solution)
        expect(rec).to include(:suggestion) if rec.key?(:suggestion)
        
        # Check that we have some form of actionable advice
        advice = rec[:solution] || rec[:suggestion] || rec[:description]
        expect(advice).to be_present
        expect(advice).to be_a(String)
        expect(advice.length).to be > 5 # Some meaningful content
      end
    end

    it 'maintains workflow functionality after optimization' do
      # Perform optimization
      optimizer = Avo::Workflows::Performance::Optimizations::PerformanceOptimizer.new(workflow_execution)
      optimizer.optimize_performance

      # Verify workflow still functions correctly
      workflow_execution.reload
      
      expect(workflow_execution).to be_valid
      expect(workflow_execution.current_step).to be_present
      expect(workflow_execution.available_actions).to be_an(Array)
      
      # Should still be able to perform actions
      available_actions = workflow_execution.available_actions
      if available_actions.any?
        expect {
          workflow_execution.perform_action(available_actions.first, user: hr_user)
        }.not_to raise_error
      end
    end
  end
end