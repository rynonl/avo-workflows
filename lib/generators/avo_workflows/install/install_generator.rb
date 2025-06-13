# frozen_string_literal: true

require 'rails/generators'
require 'rails/generators/active_record'

module AvoWorkflows
  module Generators
    class InstallGenerator < Rails::Generators::Base
      include ActiveRecord::Generators::Migration

      source_root File.expand_path('templates', __dir__)
      desc 'Install Avo Workflows in your application'

      def create_migration
        migration_template(
          'create_avo_workflow_executions.rb.erb',
          'db/migrate/create_avo_workflow_executions.rb'
        )
      end

      def create_initializer
        template 'initializer.rb.erb', 'config/initializers/avo_workflows.rb'
      end

      def create_workflows_directory
        empty_directory 'app/avo/workflows'
        create_file 'app/avo/workflows/.keep'
      end

      def create_example_workflow
        template 'example_workflow.rb.erb', 'app/avo/workflows/example_workflow.rb'
      end

      def show_readme
        readme 'INSTALL.md' if behavior == :invoke
      end

      private

      def migration_version
        "[#{ActiveRecord::VERSION::MAJOR}.#{ActiveRecord::VERSION::MINOR}]"
      end
    end
  end
end