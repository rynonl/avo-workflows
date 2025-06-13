# Avo Workflows Installation Complete!

## What was installed:

1. **Migration**: `db/migrate/create_avo_workflow_executions.rb`
   - Run `rails db:migrate` to create the workflow executions table

2. **Initializer**: `config/initializers/avo_workflows.rb`
   - Configure your user model and other settings here

3. **Workflows Directory**: `app/avo/workflows/`
   - Place your workflow definitions here

4. **Example Workflow**: `app/avo/workflows/example_workflow.rb`
   - Demonstrates basic workflow functionality

## Next Steps:

1. Run the migration:
   ```bash
   rails db:migrate
   ```

2. Configure your user model in `config/initializers/avo_workflows.rb`:
   ```ruby
   AvoWorkflows.configure do |config|
     config.user_class = "User" # or your user model name
   end
   ```

3. Create your own workflows in `app/avo/workflows/`

4. Add workflow functionality to your Avo resources:
   ```ruby
   # In your Avo resource
   class PostResource < Avo::BaseResource
     include Avo::Workflows::ResourceMethods
     
     workflow ExampleWorkflow
   end
   ```

For more information, visit: https://github.com/avo-hq/avo-workflows