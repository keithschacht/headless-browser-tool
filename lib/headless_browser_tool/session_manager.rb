# frozen_string_literal: true

require "capybara"
require "selenium-webdriver"
require "json"
require "fileutils"
require_relative "logger"
require_relative "session_persistence"
require_relative "directory_setup"

module HeadlessBrowserTool
  class SessionManager
    SESSION_TIMEOUT = 30 * 60 # 30 minutes
    CLEANUP_INTERVAL = 60 # 1 minute
    MAX_SESSIONS = 10 # Maximum concurrent sessions

    attr_reader :sessions_dir

    def initialize(headless: true)
      @sessions = {}
      @session_data = {}
      @mutex = Mutex.new
      @headless = headless

      # Enable Capybara threadsafe mode for per-session configuration
      Capybara.threadsafe = true

      # Use common sessions directory
      @sessions_dir = DirectorySetup::SESSIONS_DIR

      # Load existing session data
      load_persisted_sessions

      # Start cleanup thread
      start_cleanup_thread

      # Register shutdown hook
      at_exit { shutdown_all_sessions }
    end

    def get_or_create_session(session_id)
      @mutex.synchronize do
        # Validate session_id
        raise ArgumentError, "Invalid session ID: #{session_id}" unless valid_session_id?(session_id)

        # Update last activity
        session_data = @session_data[session_id] ||= {
          created_at: Time.now,
          last_activity: Time.now
        }
        session_data[:last_activity] = Time.now

        # Check if we're at capacity
        cleanup_least_recently_used if !@sessions[session_id] && @sessions.size >= MAX_SESSIONS

        # Get existing session or create new one
        session = @sessions[session_id]
        
        # Check if session is still valid
        if session
          begin
            # Try to access the browser to see if it's still alive
            session.current_url
          rescue Selenium::WebDriver::Error::NoSuchWindowError, Selenium::WebDriver::Error::SessionNotCreatedError
            # Browser window was closed, remove the dead session
            HeadlessBrowserTool::Logger.log.info "Session #{session_id} browser window closed, creating new session"
            @sessions.delete(session_id)
            session = nil
          end
        end

        # Create new session if needed
        @sessions[session_id] ||= create_session(session_id)
      end
    end

    def close_session(session_id)
      @mutex.synchronize do
        if (session = @sessions.delete(session_id))
          begin
            save_session_state(session_id, session)
            session.quit
          rescue StandardError => e
            HeadlessBrowserTool::Logger.log.info "Error closing session #{session_id}: #{e.message}"
          end
        end
        @session_data.delete(session_id)
      end
    end

    def save_all_sessions
      @mutex.synchronize do
        @sessions.each do |session_id, session|
          save_session_state(session_id, session)
        end
      end
    end

    def session_info
      @mutex.synchronize do
        {
          active_sessions: @sessions.keys,
          session_count: @sessions.size,
          session_data: @session_data.transform_values do |data|
            {
              created_at: data[:created_at],
              last_activity: data[:last_activity],
              idle_time: Time.now - data[:last_activity]
            }
          end
        }
      end
    end

    private

    def register_driver
      Capybara.register_driver :selenium_chrome do |app|
        options = Selenium::WebDriver::Chrome::Options.new

        # Basic arguments
        options.add_argument("--headless") if @headless
        options.add_argument("--no-sandbox")
        options.add_argument("--disable-dev-shm-usage")
        options.add_argument("--disable-gpu") if @headless

        # Stealth mode arguments to avoid detection
        options.add_argument("--disable-blink-features=AutomationControlled")
        options.exclude_switches = ["enable-automation"]
        options.add_preference("credentials_enable_service", false)
        options.add_preference("profile.password_manager_enabled", false)

        # Additional anti-detection measures
        options.add_argument("--disable-web-security")
        options.add_argument("--disable-features=IsolateOrigins,site-per-process")
        options.add_argument("--allow-running-insecure-content")
        options.add_argument("--disable-setuid-sandbox")
        options.add_argument("--disable-infobars")
        options.add_argument("--window-size=1920,1080")
        options.add_argument("--start-maximized")
        options.add_argument("--disable-extensions")
        options.add_argument("--disable-default-apps")

        # Set a more common user agent if needed
        # options.add_argument("--user-agent=Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36")

        Capybara::Selenium::Driver.new(app, browser: :chrome, options: options)
      end
    end

    def create_session(session_id)
      HeadlessBrowserTool::Logger.log.info "Creating new Capybara session: #{session_id} (headless: #{@headless})"

      # Register the appropriate driver before creating the session
      register_driver

      # Create a new Capybara session
      # With threadsafe mode enabled, each session is isolated
      session = Capybara::Session.new(:selenium_chrome)

      # Inject anti-detection JavaScript on every page load
      inject_stealth_js(session)

      # Try to restore previous state
      restore_session_state(session_id, session)

      session
    rescue StandardError => e
      HeadlessBrowserTool::Logger.log.info "Error creating session #{session_id}: #{e.message}"
      raise
    end

    def inject_stealth_js(session)
      # This JavaScript will be executed on every page to hide automation indicators
      stealth_js = <<~JS
        // Hide webdriver property
        Object.defineProperty(navigator, 'webdriver', {
          get: () => undefined
        });

        // Remove automation indicators
        if (window.chrome) {
          window.chrome.runtime = undefined;
          Object.defineProperty(navigator, 'plugins', {
            get: () => [1, 2, 3, 4, 5]
          });
        }

        // Override permissions
        const originalQuery = window.navigator.permissions.query;
        window.navigator.permissions.query = (parameters) => (
          parameters.name === 'notifications' ?
            Promise.resolve({ state: Notification.permission }) :
            originalQuery(parameters)
        );
      JS

      # Execute on initial page
      begin
        session.execute_script(stealth_js) if session.current_url != "about:blank"
      rescue
        # Ignore errors on blank pages
      end
    end

    def save_session_state(session_id, session)
      SessionPersistence.save_session(session_id, session)
    end

    def restore_session_state(session_id, session)
      SessionPersistence.restore_session(session_id, session)
    end

    def load_persisted_sessions
      Dir.glob(File.join(@sessions_dir, "*.json")).each do |file|
        state = JSON.parse(File.read(file))
        session_id = state["session_id"]

        # Initialize session data for persisted sessions
        @session_data[session_id] = {
          created_at: Time.parse(state["saved_at"]),
          last_activity: Time.now,
          persisted: true
        }

        HeadlessBrowserTool::Logger.log.info "Found persisted session: #{session_id}"
      rescue StandardError => e
        HeadlessBrowserTool::Logger.log.info "Error loading persisted session from #{file}: #{e.message}"
      end
    end

    def start_cleanup_thread
      Thread.new do
        loop do
          sleep CLEANUP_INTERVAL
          cleanup_idle_sessions
        end
      end
    end

    def cleanup_idle_sessions
      @mutex.synchronize do
        now = Time.now
        sessions_to_close = []

        @session_data.each do |session_id, data|
          sessions_to_close << session_id if now - data[:last_activity] > SESSION_TIMEOUT
        end

        sessions_to_close.each do |session_id|
          HeadlessBrowserTool::Logger.log.info "Cleaning up idle session: #{session_id} (idle for #{(now - @session_data[session_id][:last_activity]).to_i}s)" # rubocop:disable Layout/LineLength
          close_session(session_id)
        end
      end
    rescue StandardError => e
      HeadlessBrowserTool::Logger.log.info "Error during cleanup: #{e.message}"
    end

    def cleanup_least_recently_used
      # Find the least recently used session
      lru_session = @session_data.min_by { |_, data| data[:last_activity] }&.first

      return unless lru_session

      HeadlessBrowserTool::Logger.log.info "Closing LRU session to make room: #{lru_session}"
      close_session(lru_session)
    end

    def shutdown_all_sessions
      HeadlessBrowserTool::Logger.log.info "Shutting down all sessions..."
      @mutex.synchronize do
        @sessions.each do |session_id, session|
          save_session_state(session_id, session)
          session.quit
        rescue StandardError => e
          HeadlessBrowserTool::Logger.log.info "Error shutting down session #{session_id}: #{e.message}"
        end
        @sessions.clear
      end
    end

    def valid_session_id?(session_id)
      session_id.is_a?(String) &&
        session_id.length >= 1 &&
        session_id.length <= 64 &&
        session_id.match?(/\A[a-zA-Z0-9_\-]+\z/)
    end
  end
end
