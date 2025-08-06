# frozen_string_literal: true

require_relative "test_base"
require "net/http"
require "json"

class TestClickErrorHandling < TestBase
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

      $stdout.reopen(File::NULL, "w")
      $stderr.reopen(File::NULL, "w")

      HeadlessBrowserTool::Server.start_server(
        port: @port,
        single_session: false,
        headless: true
      )
    end

    track_child_process(@server_pid)

    # Wait for server to be ready
    TestServerHelper.wait_for_server("localhost", @port, path: "/mcp")
  end

  def teardown
    TestServerHelper.stop_server_process(@server_pid) if @server_pid
    super # Call TestBase teardown
  rescue Errno::ESRCH, Errno::ECHILD
    # Process already dead
  end

  def test_click_element_not_found
    # Visit a page without the element we're trying to click
    result = make_mcp_request("tools/call", {
                                name: "visit",
                                arguments: {
                                  url: "data:text/html,<html><body><h1>Test Page</h1></body></html>"
                                }
                              })

    assert_mcp_success(result)

    # Try to click a non-existent element
    result = make_mcp_request("tools/call", {
                                name: "click",
                                arguments: {
                                  selector: "#non-existent-element"
                                }
                              })

    click_result = parse_tool_result(result)

    # Debug output
    puts "Click result: #{click_result.inspect}" if ENV["DEBUG_TESTS"]

    # Should return an error message, not throw an exception
    assert_kind_of Hash, click_result
    assert click_result["error"], "Should have an error field (got: #{click_result.inspect})"
    assert_match(/Unable to find|not found/i, click_result["error"], "Error should indicate element not found")
    assert_equal "error", click_result["status"], "Status should be 'error'"
  end

  def test_click_ambiguous_selector
    # Visit a page with multiple matching elements
    html = <<-HTML
      <html>
        <body>
          <div class="duplicate">First</div>
          <div class="duplicate">Second</div>
          <div class="duplicate">Third</div>
        </body>
      </html>
    HTML

    result = make_mcp_request("tools/call", {
                                name: "visit",
                                arguments: {
                                  url: "data:text/html,#{html.gsub(/\s+/, " ").strip}"
                                }
                              })

    assert_mcp_success(result)

    # Try to click with ambiguous selector
    result = make_mcp_request("tools/call", {
                                name: "click",
                                arguments: {
                                  selector: ".duplicate"
                                }
                              })

    click_result = parse_tool_result(result)

    # Should return an error message about ambiguous selector
    assert_kind_of Hash, click_result
    assert click_result["error"], "Should have an error field"
    assert_match(/Ambiguous|multiple|found \d+ elements/i, click_result["error"], "Error should indicate ambiguous match")
    assert_equal "error", click_result["status"], "Status should be 'error'"
  end

  def test_click_button_not_found
    # Visit a page without the button we're trying to click
    result = make_mcp_request("tools/call", {
                                name: "visit",
                                arguments: {
                                  url: "data:text/html,<html><body><h1>No Buttons Here</h1></body></html>"
                                }
                              })

    assert_mcp_success(result)

    # Try to click a non-existent button
    result = make_mcp_request("tools/call", {
                                name: "click_button",
                                arguments: {
                                  button_text_or_selector: "Submit"
                                }
                              })

    button_result = parse_tool_result(result)

    # Should return an error message, not throw an exception
    assert_kind_of Hash, button_result
    assert button_result["error"], "Should have an error field"
    assert_match(/Unable to find|not found|No button/i, button_result["error"], "Error should indicate button not found")
    assert_equal "error", button_result["status"], "Status should be 'error'"
  end

  def test_click_button_with_invalid_selector
    # Visit a page with content
    result = make_mcp_request("tools/call", {
                                name: "visit",
                                arguments: {
                                  url: "data:text/html,<html><body><button>Click Me</button></body></html>"
                                }
                              })

    assert_mcp_success(result)

    # Try to click with a CSS selector that doesn't match any button
    result = make_mcp_request("tools/call", {
                                name: "click_button",
                                arguments: {
                                  button_text_or_selector: "#non-existent-button"
                                }
                              })

    button_result = parse_tool_result(result)

    # Should return an error message, not throw an exception
    assert_kind_of Hash, button_result
    assert button_result["error"], "Should have an error field"
    assert_match(/Unable to find|not found/i, button_result["error"], "Error should indicate element not found")
    assert_equal "error", button_result["status"], "Status should be 'error'"
  end

  def test_click_disabled_element
    # Visit a page with a disabled button
    result = make_mcp_request("tools/call", {
                                name: "visit",
                                arguments: {
                                  url: "data:text/html,<html><body><button id='disabled-btn' disabled>Can't Click</button></body></html>"
                                }
                              })

    assert_mcp_success(result)

    # Try to click the disabled button
    result = make_mcp_request("tools/call", {
                                name: "click",
                                arguments: {
                                  selector: "#disabled-btn"
                                }
                              })

    click_result = parse_tool_result(result)

    # Debug output
    puts "Disabled click result: #{click_result.inspect}" if ENV["DEBUG_TESTS"]

    # Should return an error or handle gracefully
    assert_kind_of Hash, click_result
    if click_result["error"]
      assert_match(/disabled|cannot click|not interactable/i, click_result["error"], "Error should indicate element is disabled")
      assert_equal "error", click_result["status"], "Status should be 'error'"
    else
      # Or it might succeed but indicate the element was disabled
      assert click_result["element"], "Should have element info (got: #{click_result.inspect})"
      assert click_result["element"]["disabled"] || click_result["warning"], "Should indicate element was disabled"
    end
  end

  def test_click_invisible_element
    # Visit a page with an invisible element
    html = <<-HTML
      <html>
        <body>
          <button id="hidden-btn" style="display: none;">Hidden Button</button>
          <button id="invisible-btn" style="visibility: hidden;">Invisible Button</button>
        </body>
      </html>
    HTML

    result = make_mcp_request("tools/call", {
                                name: "visit",
                                arguments: {
                                  url: "data:text/html,#{html.gsub(/\s+/, " ").strip}"
                                }
                              })

    assert_mcp_success(result)

    # Try to click the hidden button
    result = make_mcp_request("tools/call", {
                                name: "click",
                                arguments: {
                                  selector: "#hidden-btn"
                                }
                              })

    click_result = parse_tool_result(result)

    # Should return an error about element not being visible/interactable
    assert_kind_of Hash, click_result
    assert click_result["error"], "Should have an error field"
    assert_match(/not visible|not interactable|Unable to find/i, click_result["error"], "Error should indicate visibility issue")
    assert_equal "error", click_result["status"], "Status should be 'error'"
  end

  def test_click_with_malformed_selector
    # Visit any page
    result = make_mcp_request("tools/call", {
                                name: "visit",
                                arguments: {
                                  url: "data:text/html,<html><body><h1>Test</h1></body></html>"
                                }
                              })

    assert_mcp_success(result)

    # Try to click with a malformed CSS selector
    result = make_mcp_request("tools/call", {
                                name: "click",
                                arguments: {
                                  selector: "##invalid..selector[["
                                }
                              })

    click_result = parse_tool_result(result)

    # Should return an error about invalid selector
    assert_kind_of Hash, click_result
    assert click_result["error"], "Should have an error field"
    assert_match(/invalid.*selector|syntax|malformed/i, click_result["error"], "Error should indicate selector issue")
    assert_equal "error", click_result["status"], "Status should be 'error'"
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

  def assert_mcp_success(response)
    assert_nil response["error"], "MCP request should succeed: #{response["error"]&.inspect}"
    assert response["result"], "MCP response should have result"
  end

  def parse_tool_result(response)
    assert_mcp_success(response)
    result = response["result"]

    # If result has content field, parse the JSON from it
    if result&.dig("content").is_a?(Array)
      content = result["content"].first
      if content && content["type"] == "text" && content["text"]
        JSON.parse(content["text"])
      else
        result
      end
    else
      result
    end
  end
end
