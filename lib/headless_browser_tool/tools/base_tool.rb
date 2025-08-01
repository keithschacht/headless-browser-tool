# frozen_string_literal: true

require "fast_mcp"
require_relative "../logger"

module HeadlessBrowserTool
  module Tools
    class BaseTool < FastMcp::Tool
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

      def execute(*args, **kwargs)
        raise NotImplementedError, "Subclasses must implement the execute method"
      end

      def call(*args, **kwargs)
        result = execute(*args, **kwargs)
        HeadlessBrowserTool::Logger.log.info "CALL: #{self.class.name} #{args.inspect} #{kwargs.inspect} -> #{result.inspect}"
        result
      rescue StandardError => e
        HeadlessBrowserTool::Logger.log.error "ERROR: #{self.class.name} #{args.inspect} #{kwargs.inspect} -> #{e.message}"
        e.message
      end
    end
  end
end
