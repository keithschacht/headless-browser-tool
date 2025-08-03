# frozen_string_literal: true

require "securerandom"
require "json"
require_relative "logger"

module HeadlessBrowserTool
  class CDPExecutor
    class CDPExecutionError < StandardError; end

    def initialize(browser, context_manager, devtools = nil)
      @browser = browser
      @context_manager = context_manager
      @devtools = devtools
      @timeout = (ENV["HBT_CDP_TIMEOUT"] || "30").to_i
    end

    def execute_in_isolated_world(script, world_name: nil, retry_count: 3) # rubocop:disable Lint/UnusedMethodArgument
      ensure_devtools_available

      retries = 0
      begin
        log_debug "Getting or creating isolated context..."
        context_id = @context_manager.get_or_create_context(@browser, :isolated, @devtools)
        log_debug "Got context ID: #{context_id}"

        wrapped = wrap_with_source_url(script)

        log_debug "Executing script in context #{context_id}..."
        resp = @devtools.send_cmd("Runtime.evaluate",
                                  expression: wrapped,
                                  contextId: context_id,
                                  returnByValue: true,
                                  awaitPromise: true,
                                  timeout: @timeout * 1000)

        log_debug "Script executed successfully"
        handle_result(resp)
      rescue StandardError => e
        log_debug "CDP execution failed (attempt #{retries + 1}): #{e.message}"
        retries += 1
        @context_manager.cleanup_stale_contexts(@browser, 0) if retries > 1
        retry if retries < retry_count

        # If isolated world creation consistently fails, fall back to main world
        if e.message.include?("Failed to create isolated world") || e.message.include?("Failed to get/create context")
          log_debug "Falling back to main world execution due to isolated world failure"
          return execute_in_main_world(script)
        end

        raise CDPExecutionError, "Failed after #{retry_count} attempts: #{e.message}"
      end
    end

    def execute_in_main_world(script)
      ensure_devtools_available

      context_id = @context_manager.get_or_create_context(@browser, :main, @devtools)
      wrapped = wrap_with_source_url(script)

      resp = @devtools.send_cmd("Runtime.evaluate",
                                expression: wrapped,
                                contextId: context_id,
                                returnByValue: true,
                                awaitPromise: true,
                                timeout: @timeout * 1000)

      handle_result(resp)
    end

    private

    def ensure_devtools_available
      return if @devtools

      # Get devtools from the browser's instance variable
      @devtools = @browser.instance_variable_get(:@devtools)
      raise CDPExecutionError, "DevTools not available - CDP not initialized" unless @devtools
    rescue StandardError => e
      raise CDPExecutionError, "Failed to access DevTools: #{e.message}"
    end

    def wrap_with_source_url(script)
      url = ENV["REBROWSER_SOURCE_URL"] || "app.js"
      patches_world = ENV.fetch("REBROWSER_PATCHES_UTILITY_WORLD_NAME", nil)

      wrapped = "#{script}\n//# sourceURL=#{url}"
      wrapped = "(function(){#{wrapped}})()" if patches_world
      wrapped
    end

    def handle_result(resp)
      if resp["exceptionDetails"]
        exception = resp["exceptionDetails"]
        text = exception["text"] || exception["exception"]&.dig("description") || "Unknown error"
        raise CDPExecutionError, "Script error: #{text}"
      end

      result = resp["result"]
      return nil unless result

      # Handle different value types
      if result["type"] == "undefined"
        nil
      elsif result["value"]
        result["value"]
      elsif result["unserializableValue"]
        # Handle special values like Infinity, -Infinity, NaN
        result["unserializableValue"]
      else
        # Complex object that couldn't be serialized
        result["description"] || result["className"] || result["type"]
      end
    end

    def log_debug(message)
      return unless ENV["HBT_CDP_DEBUG"] == "true" || ENV["REBROWSER_PATCHES_DEBUG"] == "1"

      HeadlessBrowserTool::Logger.log.debug "[CDP] #{message}"
    end
  end
end
