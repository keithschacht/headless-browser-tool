# frozen_string_literal: true

require_relative "test_helper"

class TestBrowserSessionIdUnit < Minitest::Test
  def test_browser_initializer_accepts_session_id
    # Test that the Browser class constructor signature includes session_id
    # This is a simple unit test that doesn't create actual browser instances

    params = HeadlessBrowserTool::Browser.instance_method(:initialize).parameters
    param_names = params.map { |_type, name| name }

    assert_includes param_names, :session_id, "Browser#initialize should accept session_id parameter"
  end

  def test_server_passes_session_id_in_browser_new_call
    # Verify the Server.get_or_create_browser method includes session_id in Browser.new call
    # by checking the source code

    source_file = File.read("lib/headless_browser_tool/server.rb")

    # Check that Browser.new is called with session_id parameter
    assert_match(/Browser\.new\([^)]*session_id:/, source_file,
                 "Server should pass session_id when creating Browser instance")
  end

  def test_stdio_server_stores_session_id_from_env
    # Test that stdio_server.rb reads HBT_SESSION_ID from environment
    source_file = File.read("lib/headless_browser_tool/stdio_server.rb")

    assert_match(/ENV\.fetch\("HBT_SESSION_ID"/, source_file,
                 "StdioServer should read HBT_SESSION_ID from environment")

    assert_match(/Server\.session_id\s*=\s*session_id/, source_file,
                 "StdioServer should store session_id in Server class")
  end
end
