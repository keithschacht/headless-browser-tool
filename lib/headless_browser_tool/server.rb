# frozen_string_literal: true

require "sinatra/base"
require "fast_mcp"
require "rack"
require "fileutils"
require "securerandom"
require "json"
require_relative "browser"
require_relative "tools"
require_relative "session_manager"
require_relative "session_middleware"
require_relative "strict_session_middleware"
require_relative "browser_adapter"
require_relative "logger"
require_relative "session_persistence"
require_relative "directory_setup"

module HeadlessBrowserTool
  class Server < Sinatra::Base
    class << self
      attr_accessor :browser_instance, :session_manager, :single_session_mode, :show_headers, :session_id

      def start_server(options = {})
        # Initialize logger for HTTP mode
        HeadlessBrowserTool::Logger.initialize_logger(mode: :http)

        # Check if we should use single session mode
        @single_session_mode = options[:single_session] || ENV["HBT_SINGLE_SESSION"] == "true"
        @show_headers = options[:show_headers] || ENV["HBT_SHOW_HEADERS"] == "true"

        # Validate session_id option
        if options[:session_id] && !@single_session_mode
          puts "Error: --session-id can only be used with --single-session"
          exit 1
        end

        if @single_session_mode
          puts "Running in single session mode"
          if options[:session_id]
            puts "Session ID: #{options[:session_id]}"
            @session_id = options[:session_id]
          end
          @browser_instance = Browser.new(headless: options[:headless])

          # Restore session if session_id provided
          restore_single_session if @session_id
        else
          puts "Running in multi-session mode"
          @session_manager = SessionManager.new(headless: options[:headless])
        end

        # Setup directory structure
        DirectorySetup.setup_directories

        puts "Starting HeadlessBrowserTool MCP server on port #{options[:port]}"
        puts "Using fast-mcp for MCP protocol support"

        # Register shutdown hook for single session persistence
        at_exit { save_single_session } if @single_session_mode && @session_id

        # Configure and run with Puma directly
        require "puma"
        require "puma/configuration"
        require "puma/launcher"

        puma_config = Puma::Configuration.new do |config|
          config.bind "tcp://0.0.0.0:#{options[:port]}"
          config.environment "production"
          config.quiet false
          config.app Server
        end

        launcher = Puma::Launcher.new(puma_config)
        launcher.run
      end

      private

      def restore_single_session
        SessionPersistence.restore_session(@session_id, @browser_instance.session)
      end

      def save_single_session
        return unless @session_id && @browser_instance

        SessionPersistence.save_session(@session_id, @browser_instance.session)
      end
    end

    # Use strict session middleware if in multi-session mode
    use StrictSessionMiddleware unless Server.single_session_mode

    # Create MCP server instance with custom context handler
    mcp_server = FastMcp::Server.new(name: "headless-browser-tool", version: HeadlessBrowserTool::VERSION)

    # Register all browser tools
    HeadlessBrowserTool::Tools::ALL_TOOLS.each do |tool_class|
      mcp_server.register_tool(tool_class)
    end

    # Create custom transport that passes session context
    class SessionAwareTransport < FastMcp::Transports::RackTransport
      def call(env)
        # Get or create session ID for this connection
        session_id = env["hbt.session_id"]

        # Use the session ID from middleware (which handles persistence)
        # Don't generate new ones here - let the middleware handle it

        # Store session ID in thread local for tools to access
        Thread.current[:hbt_session_id] = session_id

        # Call parent
        super
      ensure
        Thread.current[:hbt_session_id] = nil
      end
    end

    # Use our custom transport
    use SessionAwareTransport, mcp_server

    # Session management endpoints
    get "/sessions" do
      if Server.single_session_mode
        { mode: "single", message: "Server is running in single session mode" }.to_json
      else
        content_type :json
        Server.session_manager.session_info.to_json
      end
    end

    delete "/sessions/:id" do
      if Server.single_session_mode
        status 400
        { error: "Cannot manage sessions in single session mode" }.to_json
      else
        Server.session_manager.close_session(params[:id])
        { message: "Session closed", session_id: params[:id] }.to_json
      end
    end

    # Default route
    get "/" do
      mode = Server.single_session_mode ? "single session" : "multi-session"
      "HeadlessBrowserTool MCP Server is running in #{mode} mode"
    end
  end
end
