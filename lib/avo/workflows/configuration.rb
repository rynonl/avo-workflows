# frozen_string_literal: true

require 'active_support/core_ext/string/inflections'

module Avo
  module Workflows
    class Configuration
      attr_accessor :user_class, :workflow_execution_class, :enabled

      def initialize
        @user_class = "User"
        @workflow_execution_class = "Avo::Workflows::WorkflowExecution"
        @enabled = true
      end

      def user_model
        return nil unless @user_class
        @user_class.constantize
      rescue NameError
        raise Error, "User class '#{@user_class}' not found. Please ensure the class exists or configure it properly."
      end

      def workflow_execution_model
        @workflow_execution_class.constantize
      rescue NameError
        raise Error, "Workflow execution class '#{@workflow_execution_class}' not found."
      end

      def enabled?
        @enabled == true
      end
    end
  end
end