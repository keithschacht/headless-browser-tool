# frozen_string_literal: true

require_relative "test_base"
require "net/http"
require "json"

class TestMaximizeWindowTool < TestBase
  def setup
    super # Call TestBase setup

    allocate_test_port
    @base_url = "http://localhost:#{@port}"
    @session_id = test_session_id

    # Start server in single session mode
    @server_pid = fork do
      # Use isolated directories
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
    super # Call TestBase teardown
  rescue Errno::ESRCH, Errno::ECHILD
    # Process already dead
  end

  def test_tool_exists
    assert defined?(HeadlessBrowserTool::Tools::MaximizeWindowTool)
  end

  def test_tool_inherits_from_base
    assert_operator HeadlessBrowserTool::Tools::MaximizeWindowTool, :<, HeadlessBrowserTool::Tools::BaseTool
  end

  def test_tool_has_execute_method
    assert HeadlessBrowserTool::Tools::MaximizeWindowTool.method_defined?(:execute)
  end

  def test_tool_registration
    all_tool_names = HeadlessBrowserTool::Tools::ALL_TOOLS.map(&:tool_name)

    assert_includes all_tool_names, "maximize_window"
  end

  def test_maximize_window_execution
    # First navigate to a test page
    result = make_mcp_request("tools/call", {
                                name: "visit",
                                arguments: { url: create_test_page_url }
                              })

    assert result["result"], "Expected result but got: #{result.inspect}"

    # Now test maximize_window
    result = make_mcp_request("tools/call", {
                                name: "maximize_window",
                                arguments: {}
                              })

    assert result["result"], "Expected result but got: #{result.inspect}"
    content = parse_tool_result(result)

    assert_equal "success", content["status"], "Expected success status but got: #{content.inspect}"
    assert content["size_before"], "Expected size_before but got: #{content.inspect}"
    assert content["size_after"], "Expected size_after but got: #{content.inspect}"
    assert content["window_handle"], "Expected window_handle but got: #{content.inspect}"

    # Verify size_before and size_after have proper structure
    %w[size_before size_after].each do |key|
      assert content[key]["width"], "Expected #{key} to have width"
      assert content[key]["height"], "Expected #{key} to have height"
    end

    # Window should be bigger after maximizing (or at least same size)
    assert_operator content["size_after"]["width"], :>=, content["size_before"]["width"], "Window width should be same or larger after maximize"
    assert_operator content["size_after"]["height"], :>=, content["size_before"]["height"], "Window height should be same or larger after maximize"
  end

  private

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

  def parse_tool_result(result)
    JSON.parse(result["result"]["content"][0]["text"])
  end

  def create_test_page_url
    "data:text/html,<html><body><h1>Test Page</h1><button>Submit</button></body></html>"
  end
end
