# frozen_string_literal: true

# Mock Avo classes for testing when Avo gem is not available
return if defined?(Avo::BaseResource)

# Create mock Avo module structure
module Avo
  class BaseResource
    attr_accessor :model

    class << self
      attr_accessor :model_class, :title, :includes

      def title=(value)
        @title = value
      end

      def includes=(value)
        @includes = value
      end

      def model_class=(value)
        @model_class = value
      end
    end

    def initialize
      @filters = []
      @actions = []
      @panels = []
    end

    def fields
      []
    end

    def filters
      []
    end

    def actions
      []
    end

    def panels
      []
    end
  end

  module Fields
    class BaseField
      attr_accessor :id, :field_type, :readonly

      class << self
        attr_accessor :field_type

        def field_type=(type)
          @field_type = type
        end
      end

      def initialize(id, **args, &block)
        @id = id
        @readonly = args[:readonly]
      end
    end
  end

  module Filters
    class SelectFilter
      class << self
        attr_accessor :name

        def name=(filter_name)
          @name = filter_name
        end
      end

      def apply(request, query, values)
        query
      end

      def options
        {}
      end

      def default
        {}
      end
    end
  end

  module Actions
    class BaseAction
      class << self
        attr_accessor :name, :visible

        def name=(action_name)
          @name = action_name
        end

        def visible=(block)
          @visible = block
        end
      end

      def fields
        []
      end

      def handle(**args)
        # Mock implementation
      end
    end
  end

  module Panels
    class BasePanel
      class << self
        attr_accessor :name, :collapsible

        def name=(panel_name)
          @name = panel_name
        end

        def collapsible=(value)
          @collapsible = value
        end
      end

      def initialize(record:, **kwargs)
        @record = record
      end

      def visible?
        true
      end

      def title
        self.class.name
      end

      def body
        "Mock panel body"
      end
    end
  end

  # Add BaseAction alias after Actions module is defined
  BaseAction = Actions::BaseAction
end

# Mock ViewComponent for testing
module ViewComponent
  class Base
    def initialize(**args)
      @args = args
    end
  end
end