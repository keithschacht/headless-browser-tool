# frozen_string_literal: true

require "sinatra/base"
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
      attr_accessor :browser_instance, :session_manager, :single_session_mode, :show_headers, :session_id, :be_human, :be_mostly_human,
                    :browser_options

      def start_server(options = {})
        # Initialize logger for HTTP mode
        HeadlessBrowserTool::Logger.initialize_logger(mode: :http)

        # Check if we should use single session mode
        self.single_session_mode = options[:single_session] || ENV["HBT_SINGLE_SESSION"] == "true"
        self.show_headers = options[:show_headers] || ENV["HBT_SHOW_HEADERS"] == "true"
        self.be_human = options[:be_human]
        self.be_mostly_human = options[:be_mostly_human]

        # Store options for lazy initialization
        self.browser_options = { headless: options[:headless], be_human: options[:be_human], be_mostly_human: options[:be_mostly_human] }

        # Validate session_id option
        if options[:session_id] && !single_session_mode
          puts "Error: --session-id can only be used with --single-session"
          exit 1
        end

        if single_session_mode
          puts "Running in single session mode"
          if options[:session_id]
            puts "Session ID: #{options[:session_id]}"
            self.session_id = options[:session_id]
          end
          # Don't create browser instance here - wait for first use
        else
          puts "Running in multi-session mode"
          self.session_manager = SessionManager.new(headless: options[:headless], be_human: options[:be_human],
                                                    be_mostly_human: options[:be_mostly_human])
        end

        # Setup directory structure
        DirectorySetup.setup_directories

        puts "Starting HeadlessBrowserTool MCP server on port #{options[:port]}"

        # Register shutdown hook for single session persistence
        at_exit { save_single_session } if single_session_mode && session_id

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

      def get_or_create_browser
        # Check if browser instance exists and is still valid
        if browser_instance
          begin
            # Check if browser has any windows - just checking current_url isn't enough
            # because a session can exist with no windows after manual close
            if browser_instance.session.windows.empty?
              HeadlessBrowserTool::Logger.log.info "Browser has no windows, creating new instance..."
              self.browser_instance = nil
            else
              # Browser has windows, check if it's actually alive
              browser_instance.session.current_url
              return browser_instance
            end
          rescue StandardError => e
            # ANY error means the browser is dead - could be closed window, terminated session, etc.
            HeadlessBrowserTool::Logger.log.info "Browser unavailable (#{e.class}: #{e.message}), creating new instance..."
            self.browser_instance = nil
          end
        end

        HeadlessBrowserTool::Logger.log.info "Creating browser instance on first use..."
        HeadlessBrowserTool::Logger.log.info "Current session_id: #{session_id.inspect}"
        HeadlessBrowserTool::Logger.log.info "Checking if session file exists: #{SessionPersistence.session_exists?(session_id) if session_id}"
        self.browser_instance = Browser.new(**browser_options, session_id: session_id)

        # Restore session if session_id provided
        restore_single_session if session_id

        browser_instance
      end

      private

      def restore_single_session
        SessionPersistence.restore_session(session_id, browser_instance.session)
      end

      def save_single_session
        return unless session_id && browser_instance

        SessionPersistence.save_session(session_id, browser_instance.session)
      rescue StandardError => e
        HeadlessBrowserTool::Logger.log.info "Error saving session during shutdown: #{e.message}"
      end
    end

    # Use session middleware that allows /mcp without session for Claude Code
    use SessionMiddleware

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

    # MCP endpoint for Claude Code
    post "/mcp" do
      content_type :json

      begin
        request.body.rewind
        body = request.body.read
        request_data = JSON.parse(body)

        case request_data["method"]
        when "initialize"
          # Accept whatever protocol version the client requests
          client_version = request_data.dig("params", "protocolVersion") || "2025-06-18"
          {
            jsonrpc: "2.0",
            id: request_data["id"],
            result: {
              protocolVersion: client_version,
              capabilities: {
                tools: { listChanged: true }
              },
              serverInfo: {
                name: "headless-browser",
                version: HeadlessBrowserTool::VERSION
              }
            }
          }.to_json

        when "tools/list"
          tools = HeadlessBrowserTool::Tools::ALL_TOOLS.map do |tool_class|
            {
              name: tool_class.tool_name,
              description: tool_class.description,
              inputSchema: tool_class.input_schema_to_json || { type: "object", properties: {}, required: [] }
            }
          end

          {
            jsonrpc: "2.0",
            id: request_data["id"],
            result: { tools: tools }
          }.to_json

        when "notifications/initialized"
          { jsonrpc: "2.0", result: nil }.to_json

        when "tools/call"
          tool_name = request_data.dig("params", "name")
          tool_args = request_data.dig("params", "arguments") || {}

          tool_class = HeadlessBrowserTool::Tools::ALL_TOOLS.find do |tc|
            tc.tool_name == tool_name
          end

          if tool_class
            session_id = env["hbt.session_id"]
            Thread.current[:hbt_session_id] = session_id

            begin
              tool = tool_class.new
              # Convert string keys to symbols
              symbolized_args = {}
              tool_args&.each { |k, v| symbolized_args[k.to_sym] = v }
              result = tool.execute(**symbolized_args)

              {
                jsonrpc: "2.0",
                id: request_data["id"],
                result: {
                  content: [{ type: "text", text: result.to_json }]
                }
              }.to_json
            ensure
              Thread.current[:hbt_session_id] = nil
            end
          else
            {
              jsonrpc: "2.0",
              id: request_data["id"],
              error: {
                code: -32_601,
                message: "Tool not found: #{tool_name}"
              }
            }.to_json
          end

        else
          {
            jsonrpc: "2.0",
            id: request_data["id"],
            error: {
              code: -32_601,
              message: "Method not found: #{request_data["method"]}"
            }
          }.to_json
        end
      rescue StandardError => e
        {
          jsonrpc: "2.0",
          id: request_data["id"],
          error: {
            code: -32_603,
            message: "Internal error: #{e.message}"
          }
        }.to_json
      end
    end

    # Default route
    get "/" do
      mode = Server.single_session_mode ? "single session" : "multi-session"
      "HeadlessBrowserTool MCP Server is running in #{mode} mode"
    end
  end
end
