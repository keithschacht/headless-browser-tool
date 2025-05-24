# frozen_string_literal: true

require_relative "base_tool"

module HeadlessBrowserTool
  module Tools
    class GetAttributeTool < BaseTool
      tool_name "get_attribute"
      description "Get an attribute value from an element"

      arguments do
        required(:selector).filled(:string).description("CSS selector of the element")
        required(:attribute_name).filled(:string).description("Name of the attribute to get")
      end

      def execute(selector:, attribute_name:)
        browser.get_attribute(selector, attribute_name)
      end
    end
  end
end
