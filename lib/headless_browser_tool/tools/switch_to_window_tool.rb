# frozen_string_literal: true

require_relative "base_tool"

module HeadlessBrowserTool
  module Tools
    class SwitchToWindowTool < BaseTool
      tool_name "switch_to_window"
      description "Switch to specific browser window/tab"

      arguments do
        required(:window_handle).filled(:string).description("Handle of the window to switch to")
      end

      def execute(window_handle:)
        previous_window = browser.current_window
        browser.switch_to_window(window_handle)

        {
          window_handle: window_handle,
          previous_window: previous_window,
          current_url: browser.current_url,
          title: browser.title,
          total_windows: browser.windows.count,
          status: "switched"
        }
      end
    end
  end
end
