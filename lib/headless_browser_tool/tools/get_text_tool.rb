# frozen_string_literal: true

require_relative "base_tool"
require_relative "get_text_of_element_tool"

module HeadlessBrowserTool
  module Tools
    class GetTextTool < BaseTool
      tool_name "get_text"
      description "Get the visible text content of an element"

      arguments do
        required(:selector).filled(:string).description("CSS selector of the element")
      end

      def execute(selector:)
        # Delegate to GetTextOfElementTool with the required selector
        markdown_tool = GetTextOfElementTool.new
        markdown_tool.execute(selector: selector)
      end
    end
  end
end
