# frozen_string_literal: true

require_relative "base_tool"

module HeadlessBrowserTool
  module Tools
    class GetCurrentUrlTool < BaseTool
      tool_name "get_current_url"
      description "Get the current page URL"

      def execute
        browser.get_current_url
      end
    end
  end
end
