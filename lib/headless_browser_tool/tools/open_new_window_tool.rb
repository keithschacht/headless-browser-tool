# frozen_string_literal: true

require_relative "base_tool"

module HeadlessBrowserTool
  module Tools
    class OpenNewWindowTool < BaseTool
      tool_name "open_new_window"
      description "Open a new browser window/tab"

      def execute
        initial_windows = browser.windows
        window_handle = browser.open_new_window

        {
          window_handle: window_handle,
          total_windows: browser.windows.count,
          previous_windows: initial_windows,
          current_window: browser.current_window,
          status: "opened"
        }
      end
    end
  end
end
