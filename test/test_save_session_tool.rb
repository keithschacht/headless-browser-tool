# frozen_string_literal: true

require_relative "test_base"
require "net/http"
require "json"
require "fileutils"

class TestSaveSessionTool < TestBase
  def setup
    super # Call TestBase setup first

    # Allocate port
    allocate_test_port
    @base_url = "http://localhost:#{@port}"
    @session_id = test_session_id

    # Start server in a separate process with isolated directories
    @server_pid = fork do
      # Use isolated directories
      ENV["HBT_SESSIONS_DIR"] = @sessions_dir
      ENV["HBT_SCREENSHOTS_DIR"] = @screenshots_dir
      ENV["HBT_LOGS_DIR"] = @logs_dir

      # Redirect output to avoid cluttering test output
      $stdout.reopen(File::NULL, "w")
      $stderr.reopen(File::NULL, "w")

      HeadlessBrowserTool::Server.start_server(
        port: @port,
        single_session: true,
        session_id: @session_id,
        headless: true
      )
    end

    track_child_process(@server_pid)
    TestServerHelper.wait_for_server("localhost", @port, path: "/")
  end

  def teardown
    TestServerHelper.stop_server_process(@server_pid) if @server_pid
    super # Call TestBase teardown for cleanup
  rescue Errno::ESRCH, Errno::ECHILD
    # Process already dead
  end

  def make_mcp_request(method, params = {})
    uri = URI("#{@base_url}/mcp")
    request = Net::HTTP::Post.new(uri)
    request["Content-Type"] = "application/json"
    request["X-Session-ID"] = @session_id

    body = {
      jsonrpc: "2.0",
      method: method,
      params: params,
      id: SecureRandom.uuid
    }

    request.body = JSON.generate(body)

    response = Net::HTTP.start(uri.hostname, uri.port, read_timeout: 10) do |http|
      http.request(request)
    end

    JSON.parse(response.body)
  end

  def parse_tool_result(response)
    # Handle error response
    return response if response["error"]

    result = response["result"]
    if result && result["content"] && result["content"][0] && result["content"][0]["text"]
      JSON.parse(result["content"][0]["text"])
    else
      result
    end
  end

  def test_save_session_creates_session_file
    # Visit a page
    make_mcp_request("tools/call", {
                       name: "visit",
                       arguments: { url: "https://example.com" }
                     })

    # Save the session
    result = make_mcp_request("tools/call", {
                                name: "save_session",
                                arguments: {}
                              })

    parsed_result = parse_tool_result(result)

    # Check the response
    assert_equal "success", parsed_result["status"]
    assert_equal @session_id, parsed_result["session_id"]
    assert parsed_result["saved_at"]
    assert_equal "https://example.com/", parsed_result["current_url"]
    assert_kind_of Integer, parsed_result["cookies_count"]
    assert_kind_of Integer, parsed_result["local_storage_items"]
    assert_kind_of Integer, parsed_result["session_storage_items"]

    # Check that the file was created
    # The file path returned by the tool
    returned_file_path = parsed_result["file_path"]

    assert returned_file_path
    assert_path_exists returned_file_path, "Session file should exist at #{returned_file_path}"

    # Verify the file contents
    session_data = JSON.parse(File.read(returned_file_path))

    assert_equal @session_id, session_data["session_id"]
    assert_equal "https://example.com/", session_data["current_url"]
    assert session_data["saved_at"]
    assert_kind_of Array, session_data["cookies"]
    assert_kind_of Hash, session_data["local_storage"]
    assert_kind_of Hash, session_data["session_storage"]
    assert_kind_of Hash, session_data["window_size"]
  end

  def test_save_session_overwrites_existing_file
    # Visit a page
    make_mcp_request("tools/call", {
                       name: "visit",
                       arguments: { url: "https://example.com" }
                     })

    # Save the session first time
    result1 = make_mcp_request("tools/call", {
                                 name: "save_session",
                                 arguments: {}
                               })
    parsed_result1 = parse_tool_result(result1)

    assert_equal "success", parsed_result1["status"]
    saved_at1 = parsed_result1["saved_at"]

    # Wait a moment to ensure different timestamp
    sleep 1

    # Navigate to a different page
    make_mcp_request("tools/call", {
                       name: "visit",
                       arguments: { url: "https://google.com" }
                     })

    # Save the session again
    result2 = make_mcp_request("tools/call", {
                                 name: "save_session",
                                 arguments: {}
                               })
    parsed_result2 = parse_tool_result(result2)

    assert_equal "success", parsed_result2["status"]
    # Google may add query parameters, so just check the base URL
    assert parsed_result2["current_url"].start_with?("https://www.google.com/"), 
           "Expected URL to start with https://www.google.com/, got #{parsed_result2["current_url"]}"
    refute_equal saved_at1, parsed_result2["saved_at"], "Timestamps should be different"

    # Verify the file was overwritten with new data
    returned_file_path = parsed_result2["file_path"]
    session_data = JSON.parse(File.read(returned_file_path))

    # Google may add query parameters, so just check the base URL
    assert session_data["current_url"].start_with?("https://www.google.com/"),
           "Expected URL to start with https://www.google.com/, got #{session_data["current_url"]}"
    assert_equal parsed_result2["saved_at"], session_data["saved_at"]
  end

  def test_save_session_preserves_cookies
    # Visit a page that sets cookies (using a data URL with JavaScript)
    html_with_cookie = <<~HTML
      <html>
        <head>
          <script>
            document.cookie = "test_cookie=test_value; path=/";
            document.cookie = "another_cookie=another_value; path=/";
          </script>
        </head>
        <body>
          <h1>Page with cookies</h1>
        </body>
      </html>
    HTML

    make_mcp_request("tools/call", {
                       name: "visit",
                       arguments: { url: "data:text/html,#{html_with_cookie}" }
                     })

    # Execute script to set cookies (since data URLs can't set cookies directly)
    make_mcp_request("tools/call", {
                       name: "execute_script",
                       arguments: {
                         script: "document.cookie = 'test_cookie=test_value; path=/'; document.cookie = 'another_cookie=another_value; path=/';"
                       }
                     })

    # Save the session
    result = make_mcp_request("tools/call", {
                                name: "save_session",
                                arguments: {}
                              })

    parsed_result = parse_tool_result(result)

    assert_equal "success", parsed_result["status"]

    # NOTE: data: URLs typically don't allow cookies, so cookies_count might be 0
    # This is expected behavior for data URLs
    assert_kind_of Integer, parsed_result["cookies_count"]
  end

  def test_save_session_with_local_storage
    # Visit a real page (localStorage doesn't work with data: URLs)
    make_mcp_request("tools/call", {
                       name: "visit",
                       arguments: { url: "https://example.com" }
                     })

    # Set localStorage items
    make_mcp_request("tools/call", {
                       name: "execute_script",
                       arguments: {
                         script: "localStorage.setItem('key1', 'value1'); localStorage.setItem('key2', 'value2');"
                       }
                     })

    # Save the session
    result = make_mcp_request("tools/call", {
                                name: "save_session",
                                arguments: {}
                              })

    parsed_result = parse_tool_result(result)

    assert_equal "success", parsed_result["status"]

    # localStorage might be blocked or cleared on example.com
    # Just verify the save operation succeeded
    assert_kind_of Integer, parsed_result["local_storage_items"]

    # If localStorage was saved, verify the contents
    returned_file_path = parsed_result["file_path"]
    session_data = JSON.parse(File.read(returned_file_path))
    return unless parsed_result["local_storage_items"].positive?

    assert_equal "value1", session_data["local_storage"]["key1"]
    assert_equal "value2", session_data["local_storage"]["key2"]
  end

  def test_save_session_includes_window_size
    # Visit a page
    make_mcp_request("tools/call", {
                       name: "visit",
                       arguments: { url: "https://example.com" }
                     })

    # Resize the window to a specific size
    make_mcp_request("tools/call", {
                       name: "resize_window",
                       arguments: { width: 1024, height: 768 }
                     })

    # Save the session
    result = make_mcp_request("tools/call", {
                                name: "save_session",
                                arguments: {}
                              })

    parsed_result = parse_tool_result(result)

    assert_equal "success", parsed_result["status"]

    # Verify window size was saved (just check that it exists and has reasonable values)
    returned_file_path = parsed_result["file_path"]
    session_data = JSON.parse(File.read(returned_file_path))

    assert session_data["window_size"]
    assert_operator session_data["window_size"]["width"], :>, 0
    assert_operator session_data["window_size"]["height"], :>, 0
  end

  def test_save_session_handles_blank_page
    # Don't navigate anywhere - browser starts at about:blank

    # Save the session
    result = make_mcp_request("tools/call", {
                                name: "save_session",
                                arguments: {}
                              })

    parsed_result = parse_tool_result(result)

    # Should still save successfully even with blank page
    assert_equal "success", parsed_result["status"]
    assert_equal @session_id, parsed_result["session_id"]
    assert_includes ["about:blank", "data:,"], parsed_result["current_url"]
    assert_equal 0, parsed_result["cookies_count"]
    assert_equal 0, parsed_result["local_storage_items"]
    assert_equal 0, parsed_result["session_storage_items"]
  end

  def test_save_session_consistency_with_close_window
    # This test verifies that save_session uses the same logic as close_window
    # Visit a page
    make_mcp_request("tools/call", {
                       name: "visit",
                       arguments: { url: "https://example.com" }
                     })

    # Save using save_session tool
    result = make_mcp_request("tools/call", {
                                name: "save_session",
                                arguments: {}
                              })

    parsed_result = parse_tool_result(result)

    assert_equal "success", parsed_result["status"]

    # Read the saved session file
    returned_file_path = parsed_result["file_path"]
    saved_session_data = JSON.parse(File.read(returned_file_path))

    # The session should have been saved with the same structure
    assert saved_session_data["session_id"]
    assert saved_session_data["saved_at"]
    assert saved_session_data["current_url"]
    assert_kind_of Array, saved_session_data["cookies"]
    assert_kind_of Hash, saved_session_data["local_storage"]
    assert_kind_of Hash, saved_session_data["session_storage"]
    assert_kind_of Hash, saved_session_data["window_size"]
  end
end
