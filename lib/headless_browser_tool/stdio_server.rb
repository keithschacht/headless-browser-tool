# frozen_string_literal: true

require "fast_mcp"
require "fileutils"
require "json"
require_relative "browser"
require_relative "tools"
require_relative "version"
require_relative "logger"
require_relative "server"
require_relative "session_persistence"
require_relative "directory_setup"

module HeadlessBrowserTool
  class StdioServer
    def self.start(options = {})
      # Setup directory structure with logs FIRST
      DirectorySetup.setup_directories(include_logs: true)

      # Initialize logger for stdio mode AFTER directories exist
      HeadlessBrowserTool::Logger.initialize_logger(mode: :stdio)

      # Check for session ID from environment
      session_id = ENV.fetch("HBT_SESSION_ID", nil)

      # Create MCP server instance
      server = FastMcp::Server.new(
        name: "headless-browser-tool",
        version: HeadlessBrowserTool::VERSION
      )

      # Create single browser instance
      # In stdio mode, always single session and headless by default
      browser = Browser.new(headless: options.fetch(:headless, true), be_human: options.fetch(:be_human, false))

      # Store browser instance for tools to access
      Server.browser_instance = browser
      Server.single_session_mode = true

      # Restore session if session ID provided
      if session_id
        HeadlessBrowserTool::Logger.log.info "Session ID provided: #{session_id}"
        SessionPersistence.restore_session(session_id, browser.session)
      end

      # Register all browser tools
      HeadlessBrowserTool::Tools::ALL_TOOLS.each do |tool_class|
        server.register_tool(tool_class)
      end

      # Log startup info to log file since stdout is used for MCP protocol
      HeadlessBrowserTool::Logger.log.info "Starting HeadlessBrowserTool MCP server in stdio mode..."
      HeadlessBrowserTool::Logger.log.info "Headless: #{options.fetch(:headless, true)}"

      # Store references for shutdown
      @browser = browser
      @session_id = session_id

      # Register shutdown hook
      at_exit do
        SessionPersistence.save_session(@session_id, @browser.session) if @session_id
      end

      # Start the server in stdio mode
      server.start
    rescue Interrupt
      HeadlessBrowserTool::Logger.log.info "Shutting down..."
      SessionPersistence.save_session(session_id, browser.session) if session_id
    ensure
      SessionPersistence.save_session(session_id, browser.session) if session_id
    end
  end
end
