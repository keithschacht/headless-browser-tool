# frozen_string_literal: true

require_relative "base_tool"
require_relative "../version"

module HeadlessBrowserTool
  module Tools
    class AboutTool < BaseTool
      tool_name "about"

      def self.description
        desc = "headless_browser_tool version #{HeadlessBrowserTool::VERSION}"

        # Include session ID info if available and Server is loaded
        if defined?(HeadlessBrowserTool::Server)
          session_id = if HeadlessBrowserTool::Server.single_session_mode && HeadlessBrowserTool::Server.session_id
                         HeadlessBrowserTool::Server.session_id
                       elsif !HeadlessBrowserTool::Server.single_session_mode
                         # In multi-session mode, we can't know the session ID at class load time
                         nil
                       end

          desc += " (session: #{session_id})" if session_id
        end

        desc
      end

      def execute
        info = {
          version: HeadlessBrowserTool::VERSION
        }

        # Add mode and session info if Server is loaded
        if defined?(HeadlessBrowserTool::Server)
          info[:mode] = HeadlessBrowserTool::Server.single_session_mode ? "single-session" : "multi-session"

          # Add session ID info
          if HeadlessBrowserTool::Server.single_session_mode && HeadlessBrowserTool::Server.session_id
            info[:session_id] = HeadlessBrowserTool::Server.session_id
          elsif !HeadlessBrowserTool::Server.single_session_mode
            # In multi-session mode, get the current session ID from thread-local storage
            session_id = Thread.current[:hbt_session_id]
            info[:session_id] = session_id if session_id && session_id != "default"
          end
        end

        info
      end
    end
  end
end
