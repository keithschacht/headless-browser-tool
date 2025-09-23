# frozen_string_literal: true

require_relative "test_helper"
require "json"
require "fileutils"
require "tempfile"

class TestSessionRestorationNilBug < Minitest::Test
  def setup
    # Create a temporary directory for session files
    @temp_dir = Dir.mktmpdir("hbt_test_session")
    @sessions_dir = File.join(@temp_dir, ".hbt", "sessions")
    FileUtils.mkdir_p(@sessions_dir)

    # Mock the DirectorySetup to use our temp directory
    HeadlessBrowserTool::DirectorySetup.const_set(:SESSIONS_DIR, @sessions_dir)

    # Create a session file with cookies that might trigger the nil error
    @session_id = "test-session-#{Time.now.to_i}"
    session_data = {
      "session_id" => @session_id,
      "saved_at" => Time.now.iso8601,
      "url" => "https://www.amazon.com",
      "cookies" => [
        {
          "name" => "test_cookie",
          "value" => "test_value",
          "domain" => ".amazon.com",
          "path" => "/",
          "secure" => true
        }
      ]
    }

    File.write(File.join(@sessions_dir, "#{@session_id}.json"), JSON.pretty_generate(session_data))
  end

  def teardown
    # Clean up temporary directory
    FileUtils.rm_rf(@temp_dir) if @temp_dir && Dir.exist?(@temp_dir)

    # Reset the Server class state
    HeadlessBrowserTool::Server.browser_instance = nil
    HeadlessBrowserTool::Server.session_id = nil
    HeadlessBrowserTool::Server.single_session_mode = nil
  end

  def test_first_visit_with_session_restoration_should_not_error
    # Configure server in single session mode with a session ID
    HeadlessBrowserTool::Server.single_session_mode = true
    HeadlessBrowserTool::Server.session_id = @session_id
    HeadlessBrowserTool::Server.browser_options = { headless: true }

    # This should trigger the bug on first call
    # The bug happens because restore_single_session tries to access
    # browser_instance.session before it's fully initialized

    visit_tool = HeadlessBrowserTool::Tools::VisitTool.new

    # This first visit should not raise an error
    # The bug would manifest as: undefined method `[]' for nil
    result = visit_tool.call(url: "https://www.amazon.com/gp/css/order-history")

    assert result, "Visit should return a result"
    assert_equal "success", result[:status], "Visit should succeed"
    assert result[:current_url], "Should have a current URL"
  end

  def test_session_restoration_handles_nil_browser_instance_safely
    # Test the specific case where browser_instance might be nil
    HeadlessBrowserTool::Server.single_session_mode = true
    HeadlessBrowserTool::Server.session_id = @session_id
    HeadlessBrowserTool::Server.browser_options = { headless: true }

    # Force browser_instance to nil to simulate the error condition
    HeadlessBrowserTool::Server.browser_instance = nil

    # Call get_or_create_browser which should handle nil safely
    browser = HeadlessBrowserTool::Server.get_or_create_browser

    assert browser, "Should create a browser instance"
    assert_respond_to browser, :session, "Browser should have a session"
    assert browser.session, "Session should not be nil"
  end

  def test_browser_initialization_with_session_fails_gracefully
    # Test that when browser session is not ready, we get a clear error message
    HeadlessBrowserTool::Server.single_session_mode = true
    HeadlessBrowserTool::Server.session_id = @session_id
    HeadlessBrowserTool::Server.browser_options = { headless: true }

    # Create a mock browser where session is nil (not ready)
    mock_browser = Object.new
    def mock_browser.session
      nil
    end

    # Mock the Browser.new to return our mock browser
    HeadlessBrowserTool::Browser.stub :new, mock_browser do
      error = assert_raises(RuntimeError) do
        HeadlessBrowserTool::Server.get_or_create_browser
      end

      assert_match(/Browser session not ready/, error.message, "Should explain session not ready")
      assert_match(/retry the operation/, error.message, "Should suggest retrying")
    end
  end
end
