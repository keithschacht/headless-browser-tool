# frozen_string_literal: true

require_relative "base_tool"

module HeadlessBrowserTool
  module Tools
    class FindElementTool < BaseTool
      tool_name "find_element"
      description "Find single element, errors if not found"

      arguments do
        required(:selector).filled(:string).description("CSS selector of the element to find")
      end

      def execute(selector:)
        browser.find_element(selector)
        "Found element: #{selector}"
      end
    end
  end
end
