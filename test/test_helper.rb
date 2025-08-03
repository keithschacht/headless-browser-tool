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
