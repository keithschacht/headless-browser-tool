# frozen_string_literal: true

require_relative "base_tool"

module HeadlessBrowserTool
  module Tools
    class HasTextTool < BaseTool
      tool_name "has_text"
      description "Check if text appears on the page"

      arguments do
        required(:text).filled(:string).description("Text to search for")
        optional(:wait_seconds).filled(:integer).description("Optional timeout in seconds")
      end

      def execute(text:, wait_seconds: nil)
        browser.has_text?(text, wait_seconds)
      end
    end
  end
end
