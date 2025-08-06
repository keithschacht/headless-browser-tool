# frozen_string_literal: true

require_relative "test_helper"
require "headless_browser_tool/browser"
require "headless_browser_tool/session_persistence"
require "json"
require "fileutils"

class TestBrowserSessionId < Minitest::Test
  def setup
    @sessions_dir = HeadlessBrowserTool::DirectorySetup::SESSIONS_DIR
    FileUtils.mkdir_p(@sessions_dir)
  end

  def teardown
    # Clean up test session files
    Dir.glob(File.join(@sessions_dir, "test-browser-*.json")).each do |file|
      FileUtils.rm_f(file)
    end
  end

  def test_browser_accepts_session_id_parameter
    session_id = "test-browser-#{Time.now.to_i}"

    browser = HeadlessBrowserTool::Browser.new(
      headless: true,
      session_id: session_id
    )

    assert_equal session_id, browser.instance_variable_get(:@session_id)

    browser.session.quit
  end

  def test_browser_generates_default_session_id_when_not_provided
    browser = HeadlessBrowserTool::Browser.new(headless: true)

    session_id = browser.instance_variable_get(:@session_id)

    assert_match(/^browser_\d+$/, session_id)

    browser.session.quit
  end

  def test_browser_with_session_id_can_be_restored
    session_id = "test-browser-#{Time.now.to_i}"
    test_url = "https://example.com/"

    # Create first browser and navigate to a URL
    browser1 = HeadlessBrowserTool::Browser.new(
      headless: true,
      session_id: session_id
    )
    browser1.visit(test_url)

    # Save the session
    HeadlessBrowserTool::SessionPersistence.save_session(session_id, browser1.session)
    browser1.session.quit

    # Create second browser with same session_id
    browser2 = HeadlessBrowserTool::Browser.new(
      headless: true,
      session_id: session_id
    )

    # Restore the session
    HeadlessBrowserTool::SessionPersistence.restore_session(session_id, browser2.session)

    # Verify the URL was restored (normalize URL comparison)
    assert_equal test_url, browser2.session.current_url

    browser2.session.quit
  end

  def test_server_passes_session_id_to_browser
    # This test verifies the Server class passes session_id correctly
    # We'll mock the browser creation to test this without starting a real server

    HeadlessBrowserTool::Server.instance_variable_set(:@session_id, "test-session")
    HeadlessBrowserTool::Server.instance_variable_set(:@browser_options, {
                                                        headless: true,
                                                        be_human: false,
                                                        be_mostly_human: false
                                                      })

    # The get_or_create_browser method should pass session_id
    browser = HeadlessBrowserTool::Server.get_or_create_browser

    assert_equal "test-session", browser.instance_variable_get(:@session_id)

    browser.session.quit
    HeadlessBrowserTool::Server.instance_variable_set(:@browser_instance, nil)
  end
end
