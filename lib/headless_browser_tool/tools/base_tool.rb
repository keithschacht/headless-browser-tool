# frozen_string_literal: true

require "fast_mcp"
require_relative "../logger"

module HeadlessBrowserTool
  module Tools
    class BaseTool < FastMcp::Tool
      # FastMCP expects tools to implement 'call', but our tools implement 'execute'
      # This method delegates to execute for backward compatibility
      def call(**args)
        execute(**args)
      rescue Selenium::WebDriver::Error::NoSuchWindowError, Selenium::WebDriver::Error::InvalidSessionIdError => e
        # Browser window was closed or session terminated, reset the browser instance and retry once
        error_type = e.class.name.split("::").last
        error_msg = e.message.split("\n").first
        HeadlessBrowserTool::Logger.log.info "Browser #{error_type}: #{error_msg}, creating new instance and retrying..."

        if HeadlessBrowserTool::Server.single_session_mode
          # Force browser recreation by setting instance to nil
          HeadlessBrowserTool::Server.instance_variable_set(:@browser_instance, nil)
        else
          # In multi-session mode, force the session manager to recreate the session
          session_id = Thread.current[:hbt_session_id]
          if session_id && HeadlessBrowserTool::Server.session_manager
            HeadlessBrowserTool::Server.session_manager.instance_variable_get(:@sessions)&.delete(session_id)
          end
        end

        # Retry the operation with a fresh browser
        execute(**args)
      end

      protected

      def browser
        if HeadlessBrowserTool::Server.single_session_mode
          # Use the single shared browser instance (lazy initialization)
          HeadlessBrowserTool::Server.get_or_create_browser
        else
          # Get session-specific browser
          session_id = Thread.current[:hbt_session_id]
          raise "No session ID provided. X-Session-ID header is required in multi-session mode" if session_id.nil? || session_id == "default"

          capybara_session = HeadlessBrowserTool::Server.session_manager.get_or_create_session(session_id)
          HeadlessBrowserTool::BrowserAdapter.new(capybara_session, session_id)
        end
      end
    end
  end
end
