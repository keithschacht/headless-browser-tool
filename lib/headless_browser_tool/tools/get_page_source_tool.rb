# frozen_string_literal: true

require_relative "base_tool"

module HeadlessBrowserTool
  module Tools
    class GetPageSourceTool < BaseTool
      tool_name "get_page_source"
      description "Get full HTML source of current page"

      def execute
        browser.get_page_source
      end
    end
  end
end
