# frozen_string_literal: true

require_relative "base_tool"

module HeadlessBrowserTool
  module Tools
    class GetPageTitleTool < BaseTool
      tool_name "get_page_title"
      description "Get the page title from <title> tag"

      def execute
        browser.get_page_title
      end
    end
  end
end
