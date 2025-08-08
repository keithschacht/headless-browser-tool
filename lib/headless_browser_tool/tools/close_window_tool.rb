# frozen_string_literal: true

require_relative "base_tool"

module HeadlessBrowserTool
  module Tools
    class CloseWindowTool < BaseTool
      tool_name "close_window"
      description "Close specific browser window/tab"

      arguments do
        required(:window_handle).filled(:string).description("Handle of the window to close")
      end

      def execute(window_handle:)
        initial_windows = browser.windows
        current_window_handle = browser.current_window.handle

        # Close the window and get the result
        result = browser.close_window(window_handle)

        # If error occurred, return the error status
        return result if result[:status] == "error"

        # If we closed the last window in single-session mode, clear the browser instance
        # This prevents "no such window" errors on the next request
        HeadlessBrowserTool::Server.browser_instance = nil if HeadlessBrowserTool::Server.single_session_mode && result[:remaining_windows].zero?

        # Use the data from the browser.close_window result instead of querying again
        # This avoids InvalidSessionIdError when the session is terminated
        {
          closed_window: window_handle,
          was_current: window_handle == current_window_handle,
          previous_windows: initial_windows.map(&:handle),
          remaining_windows: result[:remaining_windows] || 0,
          current_window: result[:current_window_handle],
          status: "closed"
        }
      end
    end
  end
end
