# frozen_string_literal: true

require_relative "base_tool"
require "reverse_markdown"

module HeadlessBrowserTool
  module Tools
    class GetPageAsMarkdownTool < BaseTool
      tool_name "get_page_as_markdown"
      description "Convert page content or a specific element to readable Markdown format. " \
                  "Returns formatted text with headings, lists, links, and tables preserved. " \
                  "Use this when you need to read page content and decide where to navigate next."

      arguments do
        optional(:selector).filled(:string).description("CSS selector of element to convert (omit to convert entire page content)")
      end

      def execute(selector: nil)
        browser.get_page_as_markdown(selector)
      end
    end
  end
end
