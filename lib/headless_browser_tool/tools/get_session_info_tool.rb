# frozen_string_literal: true

require_relative "base_tool"

module HeadlessBrowserTool
  module Tools
    class GetSessionInfoTool < BaseTool
      tool_name "get_session_info"
      description "Get information about the current browser session"

      def execute
        if HeadlessBrowserTool::Server.single_session_mode
          {
            mode: "single_session",
            session_id: HeadlessBrowserTool::Server.session_id || "shared",
            message: "Server is running in single session mode"
          }
        else
          session_id = Thread.current[:hbt_session_id] || "default"
          session_info = HeadlessBrowserTool::Server.session_manager.session_info

          current_session = session_info[:session_data][session_id]

          {
            mode: "multi_session",
            session_id: session_id,
            created_at: current_session&.dig(:created_at),
            last_activity: current_session&.dig(:last_activity),
            idle_time: current_session&.dig(:idle_time),
            active_sessions: session_info[:active_sessions],
            total_sessions: session_info[:session_count]
          }
        end
      end
    end
  end
end
