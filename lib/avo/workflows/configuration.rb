# frozen_string_literal: true

require 'active_support/core_ext/string/inflections'

module Avo
  module Workflows
    # Configuration class for Avo Workflows gem
    #
    # Handles all configuration options and provides safe access to
    # configured models with proper error handling.
    #
    # @example Basic configuration
    #   Avo::Workflows.configure do |config|
    #     config.user_class = "User"
    #     config.enabled = true
    #   end
    #
    # @example Custom user model
    #   Avo::Workflows.configure do |config|
    #     config.user_class = "Admin::User"
    #   end
    class Configuration
      # Class name for the user model
      # @return [String] the user class name
      attr_reader :user_class
      
      # Class name for the workflow execution model
      # @return [String] the workflow execution class name
      attr_reader :workflow_execution_class
      
      # Whether the workflows system is enabled
      # @return [Boolean] true if enabled
      attr_reader :enabled

      # Initialize configuration with sensible defaults
      def initialize
        @user_class = 'User'
        @workflow_execution_class = 'Avo::Workflows::WorkflowExecution'
        @enabled = true
      end

      # Sets the user class name with validation
      #
      # @param class_name [String, nil] the class name or nil to disable
      # @raise [ArgumentError] if class_name is not a string or nil
      def user_class=(class_name)
        validate_class_name!(class_name, 'user_class') if class_name
        @user_class = class_name
      end

      # Sets the workflow execution class name with validation
      #
      # @param class_name [String] the class name
      # @raise [ArgumentError] if class_name is not a valid string
      def workflow_execution_class=(class_name)
        validate_class_name!(class_name, 'workflow_execution_class')
        @workflow_execution_class = class_name
      end

      # Sets the enabled status
      #
      # @param value [Boolean] whether workflows are enabled
      def enabled=(value)
        @enabled = !!value
      end

      # Returns the user model class if available
      #
      # @return [Class, nil] the user model class or nil if not configured
      # @raise [Avo::Workflows::Error] if the class exists but cannot be loaded
      def user_model
        return nil unless @user_class

        @user_class.constantize
      rescue NameError
        raise Error, "User class '#{@user_class}' not found. Please ensure the class exists or configure it properly."
      end

      # Returns the workflow execution model class
      #
      # @return [Class] the workflow execution model class
      # @raise [Avo::Workflows::Error] if the class cannot be loaded
      def workflow_execution_model
        @workflow_execution_class.constantize
      rescue NameError
        raise Error, "Workflow execution class '#{@workflow_execution_class}' not found."
      end

      # Checks if workflows are enabled
      #
      # @return [Boolean] true if workflows are enabled
      def enabled?
        @enabled == true
      end

      # Validates the configuration
      #
      # @return [Array<String>] array of validation errors
      def validate!
        errors = []
        
        if @workflow_execution_class.blank?
          errors << 'workflow_execution_class cannot be blank'
        end

        begin
          workflow_execution_model
        rescue Error => e
          errors << e.message
        end

        if @user_class.present?
          begin
            user_model
          rescue Error => e
            errors << e.message
          end
        end

        errors
      end

      # Checks if configuration is valid
      #
      # @return [Boolean] true if configuration is valid
      def valid?
        validate!.empty?
      end

      private

      def validate_class_name!(class_name, field_name)
        unless class_name.is_a?(String) && class_name.strip.present?
          raise ArgumentError, "#{field_name} must be a non-empty string"
        end

        unless class_name.match?(/\A[A-Z][a-zA-Z0-9:]*\z/)
          raise ArgumentError, "#{field_name} must be a valid Ruby class name"
        end
      end
    end
  end
end