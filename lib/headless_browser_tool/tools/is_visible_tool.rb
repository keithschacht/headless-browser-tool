# frozen_string_literal: true

require_relative "base_tool"

module HeadlessBrowserTool
  module Tools
    class IsVisibleTool < BaseTool
      tool_name "is_visible"
      description "Check if element is visible on page"

      arguments do
        required(:selector).filled(:string).description("CSS selector of the element to check")
      end

      def execute(selector:)
        browser.is_visible?(selector)
      end
    end
  end
end
