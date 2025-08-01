# frozen_string_literal: true

require_relative "base_tool"
require_relative "../version"

module HeadlessBrowserTool
  module Tools
    class AboutTool < BaseTool
      tool_name "about"
      description "headless_browser_tool version #{HeadlessBrowserTool::VERSION}"

      def execute
        "headless_browser_tool version #{HeadlessBrowserTool::VERSION}"
      end
    end
  end
end
