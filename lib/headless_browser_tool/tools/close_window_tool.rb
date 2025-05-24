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
        current_window = browser.current_window
        browser.close_window(window_handle)

        {
          closed_window: window_handle,
          was_current: window_handle == current_window,
          previous_windows: initial_windows,
          remaining_windows: browser.windows,
          current_window: browser.current_window,
          status: "closed"
        }
      end
    end
  end
end
