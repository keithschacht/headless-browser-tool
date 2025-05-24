# frozen_string_literal: true

require_relative "base_tool"

module HeadlessBrowserTool
  module Tools
    class GetTextTool < BaseTool
      tool_name "get_text"
      description "Get the visible text content of an element"

      arguments do
        required(:selector).filled(:string).description("CSS selector of the element")
      end

      def execute(selector:)
        browser.get_text(selector)
      end
    end
  end
end
