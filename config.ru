# frozen_string_literal: true

require_relative "lib/headless_browser_tool"

# Initialize the browser instance
HeadlessBrowserTool::Server.browser_instance = HeadlessBrowserTool::Browser.new(headless: true)

run HeadlessBrowserTool::Server
