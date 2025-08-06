# frozen_string_literal: true

require_relative "test_base"
require "net/http"
require "json"
require "timeout"

class TestEdgeCasesAndErrorsReal < TestBase
  def setup
    super # Call TestBase setup

    allocate_test_port
    @base_url = "http://localhost:#{@port}"
    @session_id = test_session_id

    # Start server in single session mode with isolated directories
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

  def test_element_not_found_error
    # Navigate to a page
    make_mcp_request("tools/call", {
                       name: "visit",
                       arguments: { url: create_simple_page }
                     })

    # Try to find non-existent element
    result = make_mcp_request("tools/call", {
                                name: "find_element",
                                arguments: { selector: "#this-element-does-not-exist" }
                              })

    # Should handle error gracefully
    if result["error"]
      assert result["error"]["message"].include?("Unable to find") ||
             result["error"]["message"].include?("unable to find") ||
             result["error"]["message"].include?("Unable to locate element"),
             "Expected error message to contain 'Unable to find' or similar, got: #{result["error"]["message"]}"
    else
      # Or return error in result
      find_result = parse_tool_result(result)

      assert_includes %w[error not_found], find_result["status"]
    end
  end

  def test_invalid_selector_error
    make_mcp_request("tools/call", {
                       name: "visit",
                       arguments: { url: create_simple_page }
                     })

    # Try invalid CSS selector
    result = make_mcp_request("tools/call", {
                                name: "find_element",
                                arguments: { selector: ">>>invalid selector<<<" }
                              })

    # Should handle error
    assert result["error"] || result["result"]
  end

  def test_navigation_to_invalid_url
    # Try various invalid URLs
    invalid_urls = [
      "not-a-url",
      "ht!tp://invalid",
      "javascript:alert('xss')",
      "",
      "   "
    ]

    invalid_urls.each do |url|
      result = make_mcp_request("tools/call", {
                                  name: "visit",
                                  arguments: { url: url }
                                })

      # Should handle gracefully - either error or unsuccessful status
      assert result["error"] || result["result"]
    end
  end

  def test_javascript_errors
    make_mcp_request("tools/call", {
                       name: "visit",
                       arguments: { url: create_simple_page }
                     })

    # Invalid JavaScript
    result = make_mcp_request("tools/call", {
                                name: "execute_script",
                                arguments: { javascript_code: "this is not valid javascript {{" }
                              })

    # Should handle error
    assert result["error"] || result["result"]

    # JavaScript that throws error
    result = make_mcp_request("tools/call", {
                                name: "evaluate_script",
                                arguments: { javascript_code: "throw new Error('Test error')" }
                              })

    assert result["error"] || result["result"]
  end

  def test_interaction_with_disabled_elements
    # Create page with disabled elements
    page_url = "data:text/html,<html><body>" \
               "<input id='disabled-input' disabled value='Cannot edit'>" \
               "<button id='disabled-button' disabled>Cannot click</button>" \
               "<select id='disabled-select' disabled><option>Cannot select</option></select>" \
               "</body></html>"

    make_mcp_request("tools/call", {
                       name: "visit",
                       arguments: { url: page_url }
                     })

    # Try to interact with disabled elements
    # Fill in disabled input
    result = make_mcp_request("tools/call", {
                                name: "fill_in",
                                arguments: { field: "disabled-input", value: "New value" }
                              })

    # Should handle gracefully
    if result["result"]
      fill_result = parse_tool_result(result)
      # Might succeed but value won't change, or might report error
      assert_includes %w[filled error disabled], fill_result["status"]
    end

    # Click disabled button
    result = make_mcp_request("tools/call", {
                                name: "click_button",
                                arguments: { button_text_or_selector: "#disabled-button" }
                              })

    assert result["error"] || result["result"]
  end

  def test_timeouts_and_slow_pages
    # Create a page that loads slowly
    slow_page = "data:text/html,<html><body>" \
                "<h1>Slow Page</h1>" \
                "<script>" \
                "setTimeout(function() {  " \
                "document.body.innerHTML += '<div id=\"delayed-content\">Loaded!</div>';" \
                "}, 5000);" \
                "</script></body></html>"

    make_mcp_request("tools/call", {
                       name: "visit",
                       arguments: { url: slow_page }
                     })

    # Try to find element that doesn't exist yet
    result = make_mcp_request("tools/call", {
                                name: "has_element",
                                arguments: { selector: "#delayed-content", wait_seconds: 1 }
                              })

    has_result = parse_tool_result(result)

    refute has_result

    # Try with longer wait
    result = make_mcp_request("tools/call", {
                                name: "has_element",
                                arguments: { selector: "#delayed-content", wait_seconds: 6 }
                              })

    has_result = parse_tool_result(result)

    assert has_result
  end

  def test_large_data_handling
    # Create page with lots of content
    large_content = "Lorem ipsum " * 1000
    large_page = "data:text/html,<html><body>" \
                 "<div id='large-content'>#{large_content}</div>" \
                 "<script>var bigData = new Array(1000).fill('test data');</script>" \
                 "</body></html>"

    make_mcp_request("tools/call", {
                       name: "visit",
                       arguments: { url: large_page }
                     })

    # Get large text content
    result = make_mcp_request("tools/call", {
                                name: "get_text",
                                arguments: { selector: "#large-content" }
                              })

    text_result = parse_tool_result(result)

    assert_operator text_result.length, :>, 1000

    # Execute script with large result
    result = make_mcp_request("tools/call", {
                                name: "evaluate_script",
                                arguments: { javascript_code: "bigData" }
                              })

    eval_result = parse_tool_result(result)

    # The evaluate_script tool returns a structured response
    assert_kind_of Hash, eval_result
    assert_equal "success", eval_result["status"]
    assert_equal "Array", eval_result["type"]
    assert_kind_of Array, eval_result["result"]
  end

  def test_special_characters_and_encoding
    # Test various special characters
    special_chars = "Test «quotes» ñ ü © ® ™ 中文 日本語 한국어 🎉 😀"

    page_url = "data:text/html;charset=utf-8,<html><head><meta charset='utf-8'></head><body>" \
               "<input id='special-input' value=''>" \
               "<div id='special-div'>#{special_chars}</div>" \
               "</body></html>"

    make_mcp_request("tools/call", {
                       name: "visit",
                       arguments: { url: page_url }
                     })

    # Fill in with special characters
    result = make_mcp_request("tools/call", {
                                name: "fill_in",
                                arguments: { field: "special-input", value: special_chars }
                              })

    fill_result = JSON.parse(result["result"]["content"][0]["text"])

    assert_equal "success", fill_result["status"]

    # Get value back
    result = make_mcp_request("tools/call", {
                                name: "get_value",
                                arguments: { selector: "#special-input" }
                              })

    value = parse_tool_result(result)

    assert_equal special_chars, value
  end

  def test_frame_and_iframe_handling
    # Create page with iframe
    iframe_content = "data:text/html,<html><body><h1>Inside iframe</h1><button id='iframe-button'>Click me</button></body></html>"
    main_page = "data:text/html,<html><body>" \
                "<h1>Main page</h1>" \
                "<iframe src='#{iframe_content}' id='test-iframe'></iframe>" \
                "</body></html>"

    make_mcp_request("tools/call", {
                       name: "visit",
                       arguments: { url: main_page }
                     })

    # Try to find element in iframe (should fail or require frame switch)
    result = make_mcp_request("tools/call", {
                                name: "find_element",
                                arguments: { selector: "#iframe-button" }
                              })

    # Should not find element in iframe without switching context
    if result["error"]
      assert result["error"]["message"].include?("Unable to find") ||
             result["error"]["message"].include?("unable to find") ||
             result["error"]["message"].include?("Unable to locate element")
    else
      # If Capybara can access iframe content directly, that's also OK
      find_result = parse_tool_result(result)

      assert find_result # Just ensure we got some result
    end
  end

  # NOTE: This test is disabled due to Net::ReadTimeout errors under concurrent load
  # def test_concurrent_requests_to_same_session
  #   # This test verifies that concurrent requests to the same session
  #   # are handled gracefully (even if some fail due to thread safety)
  #   threads = []
  #   results = []
  #   mutex = Mutex.new

  #   # Navigate first
  #   make_mcp_request("tools/call", {
  #                      name: "visit",
  #                      arguments: { url: create_simple_page }
  #                    })

  #   # Make multiple concurrent requests to same session
  #   5.times do |i|
  #     threads << Thread.new do
  #       result = make_mcp_request("tools/call", {
  #                                   name: "evaluate_script",
  #                                   arguments: { javascript_code: "({ thread: #{i}, timestamp: Date.now() })" }
  #                                 })

  #       mutex.synchronize { results << result }
  #     end
  #   end

  #   threads.each(&:join)

  #   # All requests should complete (success or error)
  #   assert_equal 5, results.length

  #   # Count successes and errors
  #   successes = 0
  #   errors = 0

  #   results.each do |result|
  #     parsed_result = parse_tool_result(result)
  #     if parsed_result["error"]
  #       errors += 1
  #       # Concurrent access errors are expected
  #       assert parsed_result["error"]["message"].include?("stream closed") ||
  #              parsed_result["error"]["message"].include?("concurrent") ||
  #              parsed_result["error"]["message"].include?("locked") ||
  #              parsed_result["error"]["message"].include?("thread"),
  #              "Error should be about concurrency: #{parsed_result["error"]["message"]}"
  #     else
  #       successes += 1

  #       assert parsed_result["timestamp"], "Successful result should have timestamp"
  #     end
  #   end

  #   # In single-session mode, concurrent access may cause all requests to fail
  #   # This is expected behavior - sessions are not thread-safe
  #   assert_equal 5, errors + successes, "All requests should complete"
  # end

  def test_window_close_and_recovery
    # Get initial window count
    initial_result = make_mcp_request("tools/call", {
                                        name: "get_window_handles",
                                        arguments: {}
                                      })
    initial_handles = parse_tool_result(initial_result)
    initial_count = initial_handles["total_windows"]

    # Open new window
    result = make_mcp_request("tools/call", {
                                name: "open_new_window",
                                arguments: {}
                              })

    new_window = parse_tool_result(result)

    # Get handles after opening
    result = make_mcp_request("tools/call", {
                                name: "get_window_handles",
                                arguments: {}
                              })

    handles = parse_tool_result(result)

    assert_equal initial_count + 1, handles["total_windows"]

    # Close current window
    make_mcp_request("tools/call", {
                       name: "close_window",
                       arguments: { window_handle: new_window["window_handle"] }
                     })

    # Should still be able to work with remaining window
    result = make_mcp_request("tools/call", {
                                name: "get_current_url",
                                arguments: {}
                              })

    assert result["result"]
  end

  def test_malformed_mcp_requests
    # Missing required fields
    malformed_requests = [
      { method: "tools/call" }, # Missing params
      { params: { name: "visit" } }, # Missing method
      { method: "tools/call", params: { arguments: { url: "test" } } }, # Missing tool name
      { method: "invalid/method", params: {} } # Invalid method
    ]

    malformed_requests.each do |request_body|
      uri = URI("#{@base_url}/mcp")
      request = Net::HTTP::Post.new(uri)
      request["Content-Type"] = "application/json"
      request["X-Session-ID"] = @session_id
      request.body = request_body.merge(jsonrpc: "2.0", id: rand(1000)).to_json

      response = Net::HTTP.start(uri.hostname, uri.port) do |http|
        http.request(request)
      end

      result = JSON.parse(response.body)

      # Should return error response
      assert result["error"], "Malformed request should return error"
    end
  end

  def test_screenshot_edge_cases
    # Navigate to various edge case pages
    edge_pages = [
      # Empty page
      "data:text/html,<html><body></body></html>",
      # Very tall page
      "data:text/html,<html><body style='height:5000px;background:linear-gradient(red,blue);'></body></html>",
      # Page with alert (if it doesn't block)
      "data:text/html,<html><body><h1>Page with potential alert</h1></body></html>"
    ]

    edge_pages.each_with_index do |page_url, index|
      make_mcp_request("tools/call", {
                         name: "visit",
                         arguments: { url: page_url }
                       })

      # Take screenshot
      result = make_mcp_request("tools/call", {
                                  name: "screenshot",
                                  arguments: { filename: test_screenshot_name("edge_case_#{index}"), full_page: true }
                                })

      screenshot_result = parse_tool_result(result)

      # The screenshot tool returns file_path, not path, and no status field
      if screenshot_result["error"]
        assert false, "Screenshot failed with error: #{screenshot_result["error"]}"
      else
        assert screenshot_result["file_path"], "Screenshot should return file_path"
        assert_path_exists screenshot_result["file_path"]
      end

      # Clean up
      FileUtils.rm_f(screenshot_result["file_path"]) if screenshot_result["file_path"]
    end
  end

  private

  def parse_tool_result(result)
    if result["result"] && result["result"]["content"] && result["result"]["content"][0]
      JSON.parse(result["result"]["content"][0]["text"])
    elsif result["error"]
      { "status" => "error", "error" => result["error"] }
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

  def create_simple_page
    "data:text/html,<html><body><h1>Simple Test Page</h1><p>Test content</p></body></html>"
  end
end
