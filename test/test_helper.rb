# frozen_string_literal: true

$LOAD_PATH.unshift File.expand_path("../lib", __dir__)
require "headless_browser_tool"
require "headless_browser_tool/tools"
require "headless_browser_tool/session_manager"
require "headless_browser_tool/browser_adapter"
require "headless_browser_tool/server"
require "headless_browser_tool/logger"
require "headless_browser_tool/directory_setup"

# Ensure .hbt directory exists for tests
HeadlessBrowserTool::DirectorySetup.setup_directories(include_logs: true)

require "minitest/autorun"
require "stringio"
require_relative "test_server_helper"

# Configure Minitest to use fewer parallel workers
# Limit to 2 workers to avoid Chrome resource exhaustion
max_workers = if ENV["CI"]
                # CI environments might have more resources
                ENV.fetch("PARALLEL_WORKERS", 3).to_i
              else
                # Local development - be conservative
                ENV.fetch("PARALLEL_WORKERS", 6).to_i
              end

# Ensure we don't exceed reasonable limits
max_workers = [max_workers, 4].min
Minitest.parallel_executor = Minitest::Parallel::Executor.new(max_workers)

# Create a custom logger for tests that suppresses noisy messages
class QuietTestLogger < Logger
  SUPPRESSED_MESSAGES = [
    /Error saving session: invalid session id/,
    /Creating browser instance on first use/,
    /Browser InvalidSessionIdError.*creating new instance and retrying/,
    /\[CDP\]/, # Suppress all CDP messages
    /CDP human mode enabled/,
    /Human mode \(without CDP\) enabled/
  ].freeze

  def add(severity, message = nil, progname = nil, &)
    # Get the message string
    msg = if message.nil?
            if block_given?
              yield
            else
              progname
            end
          else
            message
          end

    # Suppress noisy messages during tests
    return if msg && SUPPRESSED_MESSAGES.any? { |pattern| msg.match?(pattern) }

    super
  end
end

# Initialize logger with our custom test logger
HeadlessBrowserTool::Logger.instance_variable_set(:@log, QuietTestLogger.new($stdout))
