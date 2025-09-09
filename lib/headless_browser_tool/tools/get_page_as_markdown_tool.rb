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
        markdown_content = browser.get_page_as_markdown(selector)

        # If it's already an error hash, return it directly
        return markdown_content if markdown_content.is_a?(Hash) && markdown_content[:error]

        # Check response size (MCP typically has issues with responses > 1MB)
        max_size = 1_000_000 # 1MB limit
        if markdown_content.bytesize > max_size
          truncated_content = markdown_content[0, 10_000] # Keep first 10KB for context
          {
            error: "Content too large",
            message: "The markdown content is #{markdown_content.bytesize} bytes, which exceeds the safe limit of " \
                     "#{max_size} bytes. Consider using a more specific selector to target a smaller portion of the page.",
            truncated_preview: truncated_content,
            original_size: markdown_content.bytesize,
            suggestions: [
              "Use a selector to target specific content (e.g., '#main-content', '.article-body')",
              "Use search_page tool to find specific text instead",
              "Use get_page_context tool for navigation metadata",
              "Break down the page analysis into smaller sections"
            ]
          }
        else
          markdown_content
        end
      end
    end
  end
end
