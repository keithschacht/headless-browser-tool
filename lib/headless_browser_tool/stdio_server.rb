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

      # Store options for lazy browser initialization
      Server.browser_options = { headless: options.fetch(:headless, true), be_human: options.fetch(:be_human, false) }
      Server.single_session_mode = true

      # Store session ID for later use
      Server.session_id = session_id
      HeadlessBrowserTool::Logger.log.info "Session ID provided: #{session_id}" if session_id

      # Register all browser tools
      HeadlessBrowserTool::Tools::ALL_TOOLS.each do |tool_class|
        server.register_tool(tool_class)
      end

      # Log startup info to log file since stdout is used for MCP protocol
      HeadlessBrowserTool::Logger.log.info "Starting HeadlessBrowserTool MCP server in stdio mode..."
      HeadlessBrowserTool::Logger.log.info "Headless: #{options.fetch(:headless, true)}"

      # Store session ID for shutdown
      @session_id = session_id

      # Register shutdown hook
      at_exit do
        # Only save if browser was actually created
        SessionPersistence.save_session(@session_id, Server.browser_instance.session) if @session_id && Server.browser_instance
      end

      # Start the server in stdio mode
      server.start
    rescue Interrupt
      HeadlessBrowserTool::Logger.log.info "Shutting down..."
      # Only save if browser was actually created
      SessionPersistence.save_session(session_id, Server.browser_instance.session) if session_id && Server.browser_instance
    ensure
      # Only save if browser was actually created
      SessionPersistence.save_session(session_id, Server.browser_instance.session) if session_id && Server.browser_instance
    end
  end
end
