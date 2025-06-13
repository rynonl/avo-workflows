# frozen_string_literal: true

require 'rails/engine'

module Avo
  module Workflows
    class Engine < ::Rails::Engine
      isolate_namespace Avo::Workflows

      config.generators do |g|
        g.test_framework :rspec
      end

      initializer "avo_workflows.load_workflows" do
        ActiveSupport.on_load(:active_record) do
          # Auto-discover and load workflow definitions
          Registry.auto_discover!
        end
      end

      # Ensure Avo is loaded before our workflows
      initializer "avo_workflows.check_avo_presence", after: "avo.load_avo" do
        unless defined?(::Avo)
          raise Error, "Avo gem is required for avo-workflows to function. Please add 'gem \"avo\"' to your Gemfile."
        end
      end
    end
  end
end