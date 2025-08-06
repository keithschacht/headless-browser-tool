# frozen_string_literal: true

require_relative "test_base"
require "net/http"
require "json"

class TestEvaluateScriptTool < TestBase
  def setup
    super # Call TestBase setup

    allocate_test_port
    @base_url = "http://localhost:#{@port}"
    @session_id = test_session_id

    # Start server in single session mode with isolated directories
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

    # Navigate to a simple page
    make_mcp_request("tools/call", {
                       name: "visit",
                       arguments: { url: create_simple_page }
                     })
  end

  def teardown
    TestServerHelper.stop_server_process(@server_pid) if @server_pid
    super # Call TestBase teardown
  rescue Errno::ESRCH, Errno::ECHILD
    # Process already dead
  end

  def test_evaluate_script_with_syntax_error
    # Test with invalid JavaScript syntax
    result = make_mcp_request("tools/call", {
                                name: "evaluate_script",
                                arguments: { javascript_code: "this is not valid javascript {{" }
                              })

    eval_result = parse_tool_result(result)

    # Should return an error message, not throw exception
    assert_equal "error", eval_result["status"]
    assert eval_result["error"], "Should have error field"
    assert_match(/syntax|error|invalid|unexpected/i, eval_result["error"], "Error message should indicate syntax error")
  end

  def test_evaluate_script_with_runtime_error
    # Test JavaScript that throws an error
    result = make_mcp_request("tools/call", {
                                name: "evaluate_script",
                                arguments: { javascript_code: "throw new Error('Test error message')" }
                              })

    eval_result = parse_tool_result(result)

    # Should return an error message, not throw exception
    assert_equal "error", eval_result["status"]
    assert eval_result["error"], "Should have error field"
    assert_match(/error|unexpected/i, eval_result["error"], "Error message should contain error indication")
  end

  def test_evaluate_script_with_undefined_reference
    # Test JavaScript that references undefined variables
    result = make_mcp_request("tools/call", {
                                name: "evaluate_script",
                                arguments: { javascript_code: "nonExistentVariable.someMethod()" }
                              })

    eval_result = parse_tool_result(result)

    # Should return an error message, not throw exception
    assert_equal "error", eval_result["status"]
    assert eval_result["error"], "Should have error field"
    assert_match(/undefined|not defined|reference|error/i, eval_result["error"], "Error message should indicate undefined reference")
  end

  def test_evaluate_script_with_null_result
    # Test JavaScript that returns null
    result = make_mcp_request("tools/call", {
                                name: "evaluate_script",
                                arguments: { javascript_code: "null" }
                              })

    eval_result = parse_tool_result(result)

    # Should handle null gracefully
    assert_equal "success", eval_result["status"]
    assert_nil eval_result["result"]
    assert_equal "NilClass", eval_result["type"]
  end

  def test_evaluate_script_with_undefined_result
    # Test JavaScript that returns undefined
    result = make_mcp_request("tools/call", {
                                name: "evaluate_script",
                                arguments: { javascript_code: "undefined" }
                              })

    eval_result = parse_tool_result(result)

    # Should handle undefined gracefully
    assert_equal "success", eval_result["status"]
    assert_nil eval_result["result"]
    assert_equal "NilClass", eval_result["type"]
  end

  def test_evaluate_script_with_successful_execution
    # Test normal successful JavaScript execution
    result = make_mcp_request("tools/call", {
                                name: "evaluate_script",
                                arguments: { javascript_code: "2 + 2" }
                              })

    eval_result = parse_tool_result(result)

    # Should return success with result
    assert_equal "success", eval_result["status"]
    assert_equal 4, eval_result["result"]
    assert_match(/Integer|Fixnum/, eval_result["type"])
  end

  private

  def parse_tool_result(result)
    if result["result"] && result["result"]["content"] && result["result"]["content"][0]
      JSON.parse(result["result"]["content"][0]["text"])
    elsif result["error"]
      # Extract error message from MCP error format
      error_message = if result["error"].is_a?(Hash)
                        result["error"]["message"] || result["error"].to_s
                      else
                        result["error"].to_s
                      end
      { "status" => "error", "error" => error_message }
    else
      { "status" => "error", "error" => "Unexpected response format", "response" => result }
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

  def create_simple_page
    "data:text/html,<html><body><h1>Simple Test Page</h1><p>Test content</p></body></html>"
  end
end
