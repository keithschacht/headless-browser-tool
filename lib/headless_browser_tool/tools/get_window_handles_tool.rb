# frozen_string_literal: true

require_relative "base_tool"

module HeadlessBrowserTool
  module Tools
    class GetWindowHandlesTool < BaseTool
      tool_name "get_window_handles"
      description "Get array of all window handles"

      def execute
        handles = browser.get_window_handles
        current_handle = browser.current_window_handle

        {
          current_window: current_handle,
          windows: handles.map.with_index do |handle, index|
            {
              handle: handle,
              index: index,
              is_current: handle == current_handle
            }
          end,
          total_windows: handles.size
        }
      end
    end
  end
end
