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

        {
          closed_window: window_handle,
          was_current: window_handle == current_window_handle,
          previous_windows: initial_windows.map(&:handle),
          remaining_windows: browser.windows.map(&:handle),
          current_window: browser.windows.any? ? browser.current_window.handle : nil,
          status: "closed"
        }
      end
    end
  end
end
