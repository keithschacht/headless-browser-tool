# frozen_string_literal: true

require "minitest/autorun"
require_relative "test_helper"
require_relative "../lib/headless_browser_tool/server"
require_relative "../lib/headless_browser_tool/tools/visit_tool"
require_relative "../lib/headless_browser_tool/tools/close_window_tool"
require_relative "../lib/headless_browser_tool/tools/get_window_handles_tool"

class TestBrowserRecovery < Minitest::Test
  def setup
    # Start in single session mode
    HeadlessBrowserTool::Server.single_session_mode = true
    @visit_tool = HeadlessBrowserTool::Tools::VisitTool.new
    @close_window_tool = HeadlessBrowserTool::Tools::CloseWindowTool.new
    @get_window_handles_tool = HeadlessBrowserTool::Tools::GetWindowHandlesTool.new
  end

  def teardown
    # Clean up browser
    begin
      browser = HeadlessBrowserTool::Server.get_or_create_browser
      browser&.quit
    rescue StandardError
      nil
    end
    HeadlessBrowserTool::Server.instance_variable_set(:@browser_instance, nil)
  end

  def test_recovery_after_closing_primary_window
    # Visit a page
    result = @visit_tool.call(url: "data:text/html,<h1>Test Page</h1>")

    assert_equal "success", result[:status]

    # Get current window
    windows = @get_window_handles_tool.call

    assert_equal 1, windows[:windows].size
    window_handle = windows[:windows].first[:handle]

    # Close the primary window
    result = @close_window_tool.call(window_handle: window_handle)

    assert_equal "closed", result[:status]
    assert_equal 0, result[:remaining_windows]

    # Try to visit a new page - should automatically recover
    result = @visit_tool.call(url: "data:text/html,<h1>New Page</h1>")

    assert_equal "success", result[:status]

    # Verify we have a new window
    windows = @get_window_handles_tool.call

    assert_equal 1, windows[:windows].size
    new_handle = windows[:windows].first[:handle]

    refute_equal window_handle, new_handle, "Should have a new window handle after recovery"
  end

  def test_no_exception_when_closing_primary_window
    # Visit a page
    result = @visit_tool.call(url: "data:text/html,<h1>Test Page</h1>")

    assert_equal "success", result[:status]

    # Get current window
    windows = @get_window_handles_tool.call
    window_handle = windows[:windows].first[:handle]

    # Close the primary window - should not raise exception
    result = @close_window_tool.call(window_handle: window_handle)

    assert_equal "closed", result[:status]
    assert_equal 0, result[:remaining_windows]
  end
end
