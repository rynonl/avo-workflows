# frozen_string_literal: true

require_relative "workflows/version"
require_relative "workflows/configuration"
require_relative "workflows/registry"
require_relative "workflows/validators"
require_relative "workflows/base"
require_relative "workflows/models/workflow_execution"
require_relative "workflows/engine" if defined?(Rails)

module Avo
  module Workflows
    class Error < StandardError; end

    # Configuration
    def self.configuration
      @configuration ||= Configuration.new
    end

    def self.configure
      yield(configuration)
    end

    def self.reset_configuration!
      @configuration = Configuration.new
    end
  end
end
