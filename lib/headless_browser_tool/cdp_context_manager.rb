# frozen_string_literal: true

require "securerandom"
require_relative "logger"

module HeadlessBrowserTool
  class CDPContextManager
    def initialize(session_id)
      @session_id = session_id
      @contexts   = {}
      @mutex      = Mutex.new
      @devtools_cache = {}
    end

    def get_or_create_context(browser, type = :isolated, devtools = nil)
      @mutex.synchronize do
        key = "#{@session_id}_#{type}"

        # Check if we have a valid cached context
        return @contexts[key][:id] if @contexts[key] && valid_context?(@contexts[key], browser, devtools)

        # Create new context
        devtools ||= get_devtools(browser)
        context_id = if type == :main
                       acquire_main_world_context(devtools)
                     else
                       create_isolated_context(browser, devtools)
                     end

        @contexts[key] = { id: context_id, time: Time.now, type: type }
        context_id
      end
    rescue StandardError => e
      HeadlessBrowserTool::Logger.log.warn "[CDP] Failed to get/create context: #{e.message}"
      raise
    end

    def cleanup_stale_contexts(browser, max_age = 300)
      @mutex.synchronize do
        now = Time.now
        @contexts.delete_if do |key, info|
          age = now - info[:time]
          stale = age > max_age || !alive?(info[:id], browser, nil)
          HeadlessBrowserTool::Logger.log.debug "[CDP] Cleaning stale context: #{key}" if stale
          stale
        end
      end
    end

    def clear_all_contexts
      @mutex.synchronize do
        @contexts.clear
        @devtools_cache.clear
      end
    end

    private

    def get_devtools(browser)
      browser_id = browser.object_id
      return @devtools_cache[browser_id] if @devtools_cache[browser_id]

      driver = browser.session.driver
      raise "DevTools not available" unless driver.respond_to?(:devtools)

      @devtools_cache[browser_id] = driver.devtools
    end

    def acquire_main_world_context(devtools)
      # Execute a simple expression to get the main world context
      resp = devtools.send_cmd("Runtime.evaluate",
                               expression: "1",
                               returnByValue: true)

      # Extract context ID from the response
      context_id = resp.dig("result", "executionContextId")
      raise "Failed to acquire main world context" unless context_id

      context_id
    end

    def create_isolated_context(_browser, devtools)
      # Get the main frame ID
      frame_tree = devtools.send_cmd("Page.getFrameTree")
      frame_id = frame_tree.dig("result", "frameTree", "frame", "id") || frame_tree.dig("frameTree", "frame", "id")

      raise "Failed to get frame ID" unless frame_id

      # Create isolated world with unique name
      world_name = "hbt_iso_#{SecureRandom.hex(8)}"

      # NOTE: rebrowser-patches uses 'grantUniveralAccess' (missing 'rs') - trying both
      begin
        if ENV["HBT_CDP_DEBUG"] == "true"
          HeadlessBrowserTool::Logger.log.debug "[CDP] Creating isolated world with frameId: #{frame_id}, worldName: #{world_name}"
        end
        resp = devtools.send_cmd("Page.createIsolatedWorld",
                                 frameId: frame_id,
                                 worldName: world_name,
                                 grantUniveralAccess: true) # Note the typo - this is what rebrowser-patches uses
      rescue StandardError => e
        HeadlessBrowserTool::Logger.log.warn "[CDP] First attempt failed with typo param: #{e.message}, trying correct spelling"
        resp = devtools.send_cmd("Page.createIsolatedWorld",
                                 frameId: frame_id,
                                 worldName: world_name,
                                 grantUniversalAccess: true)
      end

      # Handle nested response format
      context_id = resp.dig("result", "executionContextId") || resp["executionContextId"]

      HeadlessBrowserTool::Logger.log.debug "[CDP] createIsolatedWorld response: #{resp.inspect}" if ENV["HBT_CDP_DEBUG"] == "true"

      raise "Failed to create isolated world - no executionContextId in response" unless context_id

      context_id
    end

    def valid_context?(info, browser, devtools = nil)
      return false unless info && info[:id]

      # Quick time-based check
      age = Time.now - info[:time]
      return false if age > 3600 # 1 hour max

      # Actual liveness check
      alive?(info[:id], browser, devtools)
    end

    def alive?(context_id, browser, devtools = nil)
      devtools ||= get_devtools(browser)
      devtools.send_cmd("Runtime.evaluate",
                        expression: "true",
                        contextId: context_id,
                        returnByValue: true)
      true
    rescue StandardError
      false
    end
  end
end
