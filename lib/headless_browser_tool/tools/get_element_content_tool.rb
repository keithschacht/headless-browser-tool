# frozen_string_literal: true

require_relative "base_tool"
require "reverse_markdown"

module HeadlessBrowserTool
  module Tools
    class GetElementContentTool < BaseTool
      tool_name "get_element_content"
      description "Gets the innerHTML of an element (including all its children) and converts to markdown"

      arguments do
        required(:selector).filled(:string).description("CSS selector of the element to find")
      end

      def execute(selector:)
        browser.get_element_content(selector)
      end
    end
  end
end
