# frozen_string_literal: true

require "thor"

module HeadlessBrowserTool
  class CLI < Thor
    desc "start", "Start the headless browser and MCP server"
    option :port, type: :numeric, default: 4567, desc: "Port for the MCP server"
    option :headless, type: :boolean, default: true, desc: "Run browser in headless mode"
    option :single_session, type: :boolean, default: false, desc: "Use single shared browser session (legacy mode)"
    option :show_headers, type: :boolean, default: false, desc: "Show HTTP request headers for debugging"
    option :session_id, type: :string, desc: "Session ID for persistence (only with --single-session)"
    option :be_human, type: :boolean, default: false, desc: "Enable human-like browser behavior to avoid bot detection"
    option :be_mostly_human, type: :boolean, default: false, desc: "Enable human-like behavior except CDP (executes in main world)"
    def start
      require_relative "server"
      Server.start_server(options)
    end

    desc "stdio", "Start the MCP server in stdio mode"
    option :headless, type: :boolean, default: true, desc: "Run browser in headless mode"
    option :be_human, type: :boolean, default: false, desc: "Enable human-like browser behavior to avoid bot detection"
    option :be_mostly_human, type: :boolean, default: false, desc: "Enable human-like behavior except CDP (executes in main world)"
    def stdio
      require_relative "stdio_server"
      StdioServer.start(options)
    end

    desc "version", "Display version"
    def version
      puts "HeadlessBrowserTool v#{VERSION}"
    end

    def self.exit_on_failure?
      true
    end
  end
end
