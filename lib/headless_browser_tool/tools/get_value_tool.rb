# frozen_string_literal: true

require_relative "base_tool"

module HeadlessBrowserTool
  module Tools
    class GetValueTool < BaseTool
      tool_name "get_value"
      description "Get the value of an input field"

      arguments do
        required(:selector).filled(:string).description("CSS selector of the input field")
      end

      def execute(selector:)
        browser.get_value(selector)
      end
    end
  end
end
