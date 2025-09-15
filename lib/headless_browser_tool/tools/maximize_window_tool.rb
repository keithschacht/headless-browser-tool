# frozen_string_literal: true

require_relative "base_tool"

module HeadlessBrowserTool
  module Tools
    class MaximizeWindowTool < BaseTool
      tool_name "maximize_window"
      description "Maximize the browser window"

      def execute
        browser.maximize_window
      end
    end
  end
end
