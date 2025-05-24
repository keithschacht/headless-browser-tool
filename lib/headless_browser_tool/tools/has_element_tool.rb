# frozen_string_literal: true

require_relative "base_tool"

module HeadlessBrowserTool
  module Tools
    class HasElementTool < BaseTool
      tool_name "has_element"
      description "Check if an element exists on the page"

      arguments do
        required(:selector).filled(:string).description("CSS selector of the element")
        optional(:wait_seconds).filled(:integer).description("Optional timeout in seconds")
      end

      def execute(selector:, wait_seconds: nil)
        browser.has_element?(selector, wait_seconds)
      end
    end
  end
end
