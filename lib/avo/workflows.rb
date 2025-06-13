# frozen_string_literal: true

require_relative "workflows/version"
require_relative "workflows/configuration"
require_relative "workflows/registry"
require_relative "workflows/validators"
require_relative "workflows/errors"
require_relative "workflows/debugging"
require_relative "workflows/recovery"
require_relative "workflows/performance"
require_relative "workflows/performance/optimizations"
require_relative "workflows/documentation"
require_relative "workflows/base"
require_relative "workflows/models/workflow_execution"
require_relative "workflows/engine" if defined?(Rails)

# Main module for Avo Workflows gem
module Avo
  # Workflow engine that integrates with Avo admin interface
  module Workflows
    # Base error class for all workflow-related errors
    class Error < StandardError; end

    class << self
      # Returns the current configuration object
      #
      # @return [Configuration] the configuration instance
      def configuration
        @configuration ||= Configuration.new
      end

      # Configures the Avo Workflows gem
      #
      # @yield [Configuration] the configuration object
      # @example
      #   Avo::Workflows.configure do |config|
      #     config.user_class = "User"
      #     config.enabled = true
      #   end
      def configure
        yield(configuration)
      end

      # Resets configuration to defaults
      #
      # @return [Configuration] new configuration instance
      def reset_configuration!
        @configuration = Configuration.new
      end

      # Loads Avo integration components if available
      #
      # @return [Boolean] true if Avo integration was loaded
      def load_avo_integration!
        return false unless avo_available?

        require_avo_components
        true
      rescue LoadError, NameError
        false
      end

      # Checks if Avo is available for integration
      #
      # @return [Boolean] true if Avo can be integrated
      def avo_available?
        avo_defined? && base_resource_defined?
      end

      private

      def avo_defined?
        !!defined?(::Avo)
      end

      def base_resource_defined?
        !!defined?(::Avo::BaseResource)
      end

      def require_avo_components
        avo_files = %w[
          workflows/avo/workflow_resource
          workflows/avo/filters/workflow_class_filter
          workflows/avo/filters/status_filter
          workflows/avo/filters/current_step_filter
          workflows/avo/actions/perform_workflow_action
          workflows/avo/actions/assign_workflow
          workflows/avo/panels/workflow_step_panel
          workflows/avo/panels/workflow_history_panel
          workflows/avo/panels/workflow_context_panel
          workflows/avo/fields/workflow_progress_field
          workflows/avo/fields/workflow_actions_field
          workflows/avo/fields/workflow_timeline_field
          workflows/avo/components/workflow_visualizer
        ]

        avo_files.each { |file| require_relative file }
      end
    end
  end
end

# Auto-load Avo integration if available
Avo::Workflows.load_avo_integration!
