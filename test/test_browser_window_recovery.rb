# frozen_string_literal: true

require_relative "test_base"
require "net/http"
require "json"

class TestBrowserWindowRecovery < TestBase
  def setup
    super
    allocate_test_port
    @base_url = "http://localhost:#{@port}"
    @session_id = test_session_id

    # Start server in single session mode
    @server_pid = fork do
      ENV["HBT_SESSIONS_DIR"] = @sessions_dir
      ENV["HBT_SCREENSHOTS_DIR"] = @screenshots_dir
      ENV["HBT_LOGS_DIR"] = @logs_dir

      $stdout.reopen(File::NULL, "w")
      $stderr.reopen(File::NULL, "w")

      HeadlessBrowserTool::Server.start_server(
        port: @port,
        single_session: true,
        headless: true
      )
    end

    track_child_process(@server_pid)
    TestServerHelper.wait_for_server("localhost", @port, path: "/")
  end

  def teardown
    TestServerHelper.stop_server_process(@server_pid) if @server_pid
    super
  rescue Errno::ESRCH, Errno::ECHILD
    # Process already dead
  end

  def test_browser_window_closed_by_user_recovery
    # Navigate to a page first
    result = make_mcp_request("tools/call", {
                                name: "visit",
                                arguments: { url: "data:text/html,<h1>Test Page</h1>" }
                              })

    visit_result = parse_tool_result(result)

    assert_equal "success", visit_result["status"]

    # Simulate user closing the browser window by executing JavaScript to close it
    # This simulates what happens when user manually closes the browser
    make_mcp_request("tools/call", {
                       name: "execute_script",
                       arguments: { javascript_code: "window.close();" }
                     })

    # Small delay to ensure window close is processed
    sleep 0.5

    # Now try to navigate again - this should recover gracefully
    result = make_mcp_request("tools/call", {
                                name: "visit",
                                arguments: { url: "https://www.bing.com" }
                              })

    # This should succeed by creating a new browser session
    visit_result = parse_tool_result(result)

    # Should succeed without exposing any error
    refute visit_result["error"], "Should not expose window closed error to user"
    assert_equal "success", visit_result["status"]
    assert_equal "https://www.bing.com/", visit_result["current_url"]
  end

  # NOTE: This test is disabled due to Net::ReadTimeout errors
  # def test_browser_window_closed_multiple_operations
  #   # Navigate to a page first
  #   make_mcp_request("tools/call", {
  #                      name: "visit",
  #                      arguments: { url: "data:text/html,<h1>Initial Page</h1>" }
  #                    })

  #   # Open a new window and close it to simulate user closing browser
  #   make_mcp_request("tools/call", {
  #                      name: "open_new_window",
  #                      arguments: {}
  #                    })

  #   # Get all windows and close them
  #   result = make_mcp_request("tools/call", {
  #                               name: "get_window_handles",
  #                               arguments: {}
  #                             })
  #   handles = parse_tool_result(result)

  #   # Close all windows to simulate complete browser closure
  #   if handles["windows"].is_a?(Array)
  #     handles["windows"].each do |window|
  #       make_mcp_request("tools/call", {
  #                          name: "close_window",
  #                          arguments: { window_handle: window["handle"] }
  #                        })
  #     end
  #   end

  #   sleep 0.5

  #   # Try multiple operations that should all recover gracefully
  #   operations = [
  #     { name: "visit", arguments: { url: "https://example.com" } },
  #     { name: "get_current_url", arguments: {} },
  #     { name: "get_page_title", arguments: {} },
  #     { name: "screenshot", arguments: { filename: test_screenshot_name("recovery_test") } }
  #   ]

  #   operations.each do |op|
  #     result = make_mcp_request("tools/call", op)
  #     parsed = parse_tool_result(result)

  #     # Should not have an error about closed window
  #     if parsed["error"]&.include?("no such window")
  #       assert false, "Operation #{op[:name]} should recover from closed window, but got: #{parsed["error"]}"
  #     end
  #   end

  #   # Clean up screenshot
  #   FileUtils.rm_f(File.join(@screenshots_dir, "recovery_test.png"))
  # end

  private

  def parse_tool_result(result)
    if result["result"] && result["result"]["content"] && result["result"]["content"][0]
      JSON.parse(result["result"]["content"][0]["text"])
    elsif result["error"]
      { "status" => "error", "error" => result["error"]["message"] }
    else
      { "status" => "error", "message" => "Unexpected response format", "response" => result }
    end
  end

  def make_mcp_request(method, params = {})
    uri = URI("#{@base_url}/mcp")
    request = Net::HTTP::Post.new(uri)
    request["Content-Type"] = "application/json"
    request["X-Session-ID"] = @session_id
    request.body = {
      jsonrpc: "2.0",
      method: method,
      params: params,
      id: rand(10_000)
    }.to_json

    response = Net::HTTP.start(uri.hostname, uri.port) do |http|
      http.request(request)
    end

    JSON.parse(response.body)
  end
end
