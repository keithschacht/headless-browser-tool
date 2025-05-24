# frozen_string_literal: true

require "securerandom"
require_relative "logger"

module HeadlessBrowserTool
  class SessionMiddleware
    # Headers to check for session ID (in priority order)
    SESSION_HEADERS = %w[
      HTTP_X_SESSION_ID
      HTTP_X_CLIENT_ID
    ].freeze

    DEFAULT_SESSION = "default"

    # Class-level session storage for MCP connections
    @mcp_sessions = {}
    @session_mutex = Mutex.new

    class << self
      attr_accessor :mcp_sessions, :session_mutex
    end

    def initialize(app)
      @app = app
    end

    def call(env)
      # Log request headers if enabled
      log_request_headers(env) if HeadlessBrowserTool::Server.show_headers

      # Extract session ID from headers first
      session_id = extract_session_id(env)

      # For MCP connections, try to maintain session continuity
      session_id = get_or_create_mcp_session(env) if session_id == DEFAULT_SESSION && mcp_request?(env)

      # Store in environment for downstream use
      env["hbt.session_id"] = session_id

      # Call the app
      status, headers, response = @app.call(env)

      # Add session ID to response headers
      headers["X-Session-ID"] = session_id

      # For MCP SSE connections, send session info
      if env["PATH_INFO"] == "/mcp/sse" && session_id != DEFAULT_SESSION
        # Store for future requests from this client
        store_mcp_session(env, session_id)
      end

      [status, headers, response]
    end

    private

    def extract_session_id(env)
      # Check for explicit session headers
      SESSION_HEADERS.each do |header|
        if (value = env[header])
          sanitized = sanitize_session_id(value)
          return sanitized if sanitized
        end
      end

      # Default session if none provided
      DEFAULT_SESSION
    end

    def sanitize_session_id(value)
      return nil if value.nil? || value.empty?

      # Ensure it's alphanumeric with underscores/hyphens only
      sanitized = value.gsub(/[^a-zA-Z0-9_\-]/, "")

      # Limit length
      sanitized = sanitized[0..64]

      # Return nil if invalid
      return nil if sanitized.empty?

      sanitized
    end

    def mcp_request?(env)
      env["PATH_INFO"]&.start_with?("/mcp")
    end

    def get_or_create_mcp_session(env)
      client_key = generate_client_key(env)

      self.class.session_mutex.synchronize do
        # Check if we have a session for this client
        if self.class.mcp_sessions[client_key]
          self.class.mcp_sessions[client_key][:last_seen] = Time.now
          return self.class.mcp_sessions[client_key][:session_id]
        end

        # Create new session
        session_id = "mcp_#{SecureRandom.hex(8)}"
        self.class.mcp_sessions[client_key] = {
          session_id: session_id,
          created_at: Time.now,
          last_seen: Time.now
        }

        # Clean old sessions
        cleanup_old_sessions

        session_id
      end
    end

    def store_mcp_session(env, session_id)
      client_key = generate_client_key(env)

      self.class.session_mutex.synchronize do
        self.class.mcp_sessions[client_key] = {
          session_id: session_id,
          created_at: Time.now,
          last_seen: Time.now
        }
      end
    end

    def generate_client_key(env)
      # Use IP + User-Agent as a simple client identifier
      # This isn't perfect but works for most cases
      ip = env["REMOTE_ADDR"] || "unknown"
      user_agent = env["HTTP_USER_AGENT"] || "unknown"
      "#{ip}:#{user_agent.hash}"
    end

    def cleanup_old_sessions
      # Remove sessions older than 1 hour
      cutoff = Time.now - 3600
      self.class.mcp_sessions.delete_if { |_, data| data[:last_seen] < cutoff }
    end

    def log_request_headers(env)
      HeadlessBrowserTool::Logger.log.info "\n=== REQUEST HEADERS ==="
      HeadlessBrowserTool::Logger.log.info "Method: #{env["REQUEST_METHOD"]} #{env["PATH_INFO"]}"
      HeadlessBrowserTool::Logger.log.info "Remote IP: #{env["REMOTE_ADDR"]}"

      # Log all HTTP headers
      env.select { |k, _v| k.start_with?("HTTP_") }.each do |key, value|
        header_name = key.sub("HTTP_", "").split("_").map(&:capitalize).join("-")
        HeadlessBrowserTool::Logger.log.info "#{header_name}: #{value}"
      end

      # Log specific session-related info
      HeadlessBrowserTool::Logger.log.info "Session ID from headers: #{extract_session_id(env)}"
      HeadlessBrowserTool::Logger.log.info "Client Key: #{generate_client_key(env)}"
      HeadlessBrowserTool::Logger.log.info "=====================\n"
    end
  end
end
