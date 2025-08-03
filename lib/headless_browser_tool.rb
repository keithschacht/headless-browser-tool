# frozen_string_literal: true

require_relative "headless_browser_tool/version"
require_relative "headless_browser_tool/cli"
require_relative "headless_browser_tool/browser"

module HeadlessBrowserTool
  class Error < StandardError; end
end
