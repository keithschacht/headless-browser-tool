# frozen_string_literal: true

require "securerandom"
require "json"
require_relative "logger"
require_relative "cdp_human_scripts"
require_relative "cdp_context_manager"
require_relative "cdp_executor"

module HeadlessBrowserTool
  module CDPHuman # rubocop:disable Metrics/ModuleLength
    class CDPError < StandardError; end

    def setup_cdp(driver)
      HeadlessBrowserTool::Logger.log.debug "[CDP] Starting CDP setup..."

      @driver = driver
      HeadlessBrowserTool::Logger.log.debug "[CDP] Getting devtools..."

      # Try to load selenium/devtools first
      begin
        require "selenium/devtools"
      rescue LoadError => e
        HeadlessBrowserTool::Logger.log.error "[CDP] Failed to load selenium/devtools: #{e.message}"
        HeadlessBrowserTool::Logger.log.warn "[CDP] CDP features will be disabled. Falling back to JS injection only."
        @devtools = nil
        @cdp_executor = nil
        return false
      end

      @devtools = driver.devtools
      HeadlessBrowserTool::Logger.log.debug "[CDP] Devtools obtained"

      @main_frame_id = nil
      @cdp_context_manager = CDPContextManager.new("browser_#{driver.object_id}")
      @cdp_executor = CDPExecutor.new(self, @cdp_context_manager, @devtools)

      # Enable necessary domains
      HeadlessBrowserTool::Logger.log.debug "[CDP] Enabling domains..."
      enable_cdp_domains

      # Get main frame ID
      HeadlessBrowserTool::Logger.log.debug "[CDP] Fetching frame ID..."
      @main_frame_id = fetch_frame_id

      # Register navigation handler
      HeadlessBrowserTool::Logger.log.debug "[CDP] Registering navigation handler..."
      register_navigation_handler

      # Inject human scripts
      HeadlessBrowserTool::Logger.log.debug "[CDP] Injecting human scripts..."
      inject_human_scripts

      HeadlessBrowserTool::Logger.log.debug "[CDP] Human mode initialized successfully"
      true
    rescue StandardError => e
      HeadlessBrowserTool::Logger.log.error "[CDP] Failed to setup CDP: #{e.message}"
      @devtools = nil
      @cdp_executor = nil
      false
    end

    def cdp_available?
      !@devtools.nil? && !@cdp_executor.nil?
    end

    def execute_cdp_script(script)
      raise CDPError, "CDP not initialized" unless cdp_available?

      HeadlessBrowserTool::Logger.log.debug "[CDP] execute_cdp_script called" if ENV["HBT_CDP_DEBUG"] == "true"
      @cdp_executor.execute_in_isolated_world(script)
    end

    private

    def enable_cdp_domains
      @devtools.send_cmd("Page.enable")
      @devtools.send_cmd("Runtime.enable")
      @devtools.send_cmd("Network.enable")

      # Don't override user agent - Chrome's default is already correct!
    rescue StandardError => e
      HeadlessBrowserTool::Logger.log.warn "[CDP] Failed to enable domains: #{e.message}"
    end

    def fetch_frame_id
      response = @devtools.send_cmd("Page.getFrameTree")

      frame_id = response.dig("result", "frameTree", "frame", "id") || response.dig("frameTree", "frame", "id")

      raise CDPError, "Failed to get main frame ID" unless frame_id

      frame_id
    rescue StandardError => e
      HeadlessBrowserTool::Logger.log.error "[CDP] Failed to fetch frame ID: #{e.message}"
      raise
    end

    def register_navigation_handler
      @devtools.on("Page.frameNavigated") do |params|
        frame = params["frame"]
        if frame && frame["id"] == @main_frame_id
          HeadlessBrowserTool::Logger.log.debug "[CDP] Main frame navigated, clearing contexts and re-injecting scripts"
          clear_context_cache
          inject_human_scripts
        end
      end

      # Also handle frame lifecycle events
      @devtools.on("Page.frameStartedLoading") do |params|
        HeadlessBrowserTool::Logger.log.debug "[CDP] Main frame started loading" if params["frameId"] == @main_frame_id
      end
    rescue StandardError => e
      # Suppress known Chrome/Selenium version mismatch warnings
      unless e.message.include?("wrong constant name") && e.message.include?("Selenium::DevTools")
        HeadlessBrowserTool::Logger.log.warn "[CDP] Failed to register navigation handler: #{e.message}"
      end
    end

    def clear_context_cache
      @cdp_context_manager&.clear_all_contexts
    end

    def inject_human_scripts
      scripts = [
        { name: "core", source: core_script },
        { name: "chrome", source: chrome_script },
        { name: "plugins", source: plugins_script },
        { name: "permissions", source: permissions_script },
        { name: "dimensions", source: dimensions_script }
      ]

      scripts.each do |script_info|
        inject_single_script(script_info[:name], script_info[:source])
      end
    rescue StandardError => e
      HeadlessBrowserTool::Logger.log.error "[CDP] Failed to inject human scripts: #{e.message}"
      raise
    end

    def inject_single_script(name, source)
      # Don't use worldName to inject into main world instead of isolated world
      @devtools.send_cmd("Page.addScriptToEvaluateOnNewDocument",
                         source: source,
                         runImmediately: true)

      HeadlessBrowserTool::Logger.log.debug "[CDP] Injected #{name} script into main world"
    rescue StandardError => e
      HeadlessBrowserTool::Logger.log.warn "[CDP] Failed to inject #{name} script: #{e.message}"
      # Don't re-raise - allow other scripts to be injected
    end

    def core_script
      <<~JS
        // Remove webdriver property
        Object.defineProperty(navigator, 'webdriver', {
          get: () => undefined,
          configurable: true
        });

        // Remove automation indicators
        delete window.__puppeteer_utility_world__;
        delete window.__playwright_utility_world__;

        // Don't modify userAgent or userAgentData - Chrome handles this correctly by default!

        // Fix for Chrome headless detection
        if (window.chrome) {
          const originalQuery = window.navigator.permissions.query;
          window.navigator.permissions.query = (parameters) => (
            parameters.name === 'notifications' ?
              Promise.resolve({ state: window.Notification.permission }) :
              originalQuery(parameters)
          );
        }
      JS
    end

    def chrome_script
      CDPHumanScripts.chrome_script
    end

    def plugins_script
      CDPHumanScripts.plugins_script
    end

    def permissions_script
      <<~JS
        // Override permissions API
        if (navigator.permissions && navigator.permissions.query) {
          const originalQuery = navigator.permissions.query.bind(navigator.permissions);
          navigator.permissions.query = (params) => {
            if (params.name === 'notifications') {
              return Promise.resolve({#{" "}
                state: Notification.permission,
                onchange: null
              });
            }
            return originalQuery(params);
          };
        }
      JS
    end

    def dimensions_script
      <<~JS
        // Fix window dimensions for headless detection
        if (window.outerWidth === 0 && window.outerHeight === 0) {
          Object.defineProperty(window, 'outerWidth', {
            get: () => window.innerWidth,
            configurable: true
          });
          Object.defineProperty(window, 'outerHeight', {
            get: () => window.innerHeight + 74, // Account for browser chrome
            configurable: true
          });
        }

        // Additional screen fixes
        if (screen.width === 0 || screen.height === 0) {
          Object.defineProperty(screen, 'width', {
            get: () => 1920,
            configurable: true
          });
          Object.defineProperty(screen, 'height', {
            get: () => 1080,
            configurable: true
          });
        }
      JS
    end
  end
end
