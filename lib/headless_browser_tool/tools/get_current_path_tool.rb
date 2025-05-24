# frozen_string_literal: true

require_relative "base_tool"

module HeadlessBrowserTool
  module Tools
    class GetCurrentPathTool < BaseTool
      tool_name "get_current_path"
      description "Get current path without domain"

      def execute
        browser.get_current_path
      end
    end
  end
end
