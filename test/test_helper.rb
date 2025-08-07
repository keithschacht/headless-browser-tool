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

# Create a null logger for tests that suppresses all output
class NullLogger < Logger
  def initialize
    # Initialize with a StringIO that we never use
    super(StringIO.new)
    self.level = Logger::FATAL
  end

  def add(_severity, _message = nil, _progname = nil, &)
    # Suppress all log messages during tests
    nil
  end
end

# Initialize logger with our null logger for tests
HeadlessBrowserTool::Logger.instance_variable_set(:@log, NullLogger.new)
