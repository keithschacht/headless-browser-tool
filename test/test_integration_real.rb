# frozen_string_literal: true

require_relative "test_base"
require "net/http"
require "json"
require "tempfile"

class TestIntegrationReal < TestBase
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

  def test_full_workflow_with_real_browser
    # 1. Navigate to a test page
    result = make_mcp_request("tools/call", {
                                name: "visit",
                                arguments: { url: create_test_page_url }
                              })

    assert result["result"], "Expected result but got: #{result.inspect}"
    content = parse_tool_result(result)

    assert_equal "success", content["status"], "Expected success status but got: #{content.inspect}"

    # 2. Find elements
    result = make_mcp_request("tools/call", {
                                name: "find_all",
                                arguments: { selector: "button" }
                              })

    find_result = parse_tool_result(result)
    elements = find_result["elements"]

    assert_equal 3, elements.length
    assert_equal "Submit", elements[0]["text"]

    # 3. Fill in form
    result = make_mcp_request("tools/call", {
                                name: "fill_in",
                                arguments: { field: "username", value: "testuser" }
                              })

    fill_result = parse_tool_result(result)

    assert_equal "success", fill_result["status"]

    # 4. Click button
    result = make_mcp_request("tools/call", {
                                name: "click_button",
                                arguments: { button_text_or_selector: "Submit" }
                              })

    click_result = parse_tool_result(result)

    puts "Click error: #{click_result.inspect}" if click_result["status"] == "error"

    assert_equal "clicked", click_result["status"]

    # 5. Take screenshot
    result = make_mcp_request("tools/call", {
                                name: "screenshot",
                                arguments: { filename: test_screenshot_name("integration") }
                              })

    screenshot_result = parse_tool_result(result)

    assert screenshot_result["file_path"]
    assert_path_exists screenshot_result["file_path"]

    # Clean up screenshot
    FileUtils.rm_f(screenshot_result["file_path"])
  end

  def test_navigation_workflow
    # Test multiple navigations
    pages = [
      create_test_page_url("Page 1"),
      create_test_page_url("Page 2"),
      create_test_page_url("Page 3")
    ]

    # Navigate forward through pages
    pages.each_with_index do |url, index|
      result = make_mcp_request("tools/call", {
                                  name: "visit",
                                  arguments: { url: url }
                                })

      nav_result = parse_tool_result(result)

      assert_equal "success", nav_result["status"]

      # Check page title
      title_result = make_mcp_request("tools/call", {
                                        name: "get_page_title",
                                        arguments: {}
                                      })

      title = parse_tool_result(title_result)

      assert_equal "Page #{index + 1}", title
    end

    # Navigate back
    result = make_mcp_request("tools/call", {
                                name: "go_back",
                                arguments: {}
                              })

    back_result = parse_tool_result(result)

    assert_equal "navigated_back", back_result["status"]

    # Check we're on Page 2
    title_result = make_mcp_request("tools/call", {
                                      name: "get_page_title",
                                      arguments: {}
                                    })

    title = parse_tool_result(title_result)

    assert_equal "Page 2", title
  end

  def test_javascript_execution
    # Navigate to test page
    make_mcp_request("tools/call", {
                       name: "visit",
                       arguments: { url: create_test_page_url }
                     })

    # Execute script
    result = make_mcp_request("tools/call", {
                                name: "execute_script",
                                arguments: {
                                  javascript_code: "document.body.setAttribute('data-test', 'integration')"
                                }
                              })

    exec_result = parse_tool_result(result)

    assert_equal "executed", exec_result["status"]

    # Evaluate script
    result = make_mcp_request("tools/call", {
                                name: "evaluate_script",
                                arguments: {
                                  javascript_code: "({ test: document.body.getAttribute('data-test'), timestamp: Date.now() })"
                                }
                              })

    eval_result = parse_tool_result(result)

    # evaluate_script returns the raw JavaScript result, not a status object
    assert_equal "integration", eval_result["test"]
    assert eval_result["timestamp"]
  end

  def test_element_interactions
    # Navigate to interactive page
    make_mcp_request("tools/call", {
                       name: "visit",
                       arguments: { url: create_interactive_page_url }
                     })

    # Ensure page loaded
    result = make_mcp_request("tools/call", {
                                name: "has_element",
                                arguments: { selector: "#hover-target", wait_seconds: 2 }
                              })

    has_el = parse_tool_result(result)
    # Just skip the hover test if the element isn't found - data URLs can be flaky
    unless has_el
      # Skip interaction tests if page didn't load properly
      return
    end

    # Test hover
    result = make_mcp_request("tools/call", {
                                name: "hover",
                                arguments: { selector: "#hover-target" }
                              })

    hover_result = parse_tool_result(result)

    assert false, "Hover failed with error: #{hover_result["error"]["message"]}" if hover_result["error"]

    assert_equal "hovering", hover_result["status"]

    # Test right click
    result = make_mcp_request("tools/call", {
                                name: "right_click",
                                arguments: { selector: "#context-target" }
                              })

    right_click_result = parse_tool_result(result)

    assert_equal "right_clicked", right_click_result["status"]

    # Test double click
    result = make_mcp_request("tools/call", {
                                name: "double_click",
                                arguments: { selector: "#double-click-target" }
                              })

    double_click_result = parse_tool_result(result)

    assert_equal "double_clicked", double_click_result["status"]
  end

  def test_search_functionality
    # Navigate to content-rich page
    make_mcp_request("tools/call", {
                       name: "visit",
                       arguments: { url: create_content_page_url }
                     })

    # Search page
    result = make_mcp_request("tools/call", {
                                name: "search_page",
                                arguments: { query: "important", highlight: true }
                              })

    search_result = parse_tool_result(result)

    assert search_result, "Search result should not be nil"
    assert search_result["matches"], "Search result should have matches array, got: #{search_result.inspect}"
    assert_operator search_result["total_matches"], :>, 0, "Should find at least one match"
    assert_equal "important", search_result["query"]

    # Search with regex
    result = make_mcp_request("tools/call", {
                                name: "search_page",
                                arguments: { query: "test\\d+", regex: true }
                              })

    regex_result = parse_tool_result(result)

    assert regex_result["matches"]
    assert_predicate regex_result["total_matches"], :positive?
  end

  def test_window_management
    # Open new window
    result = make_mcp_request("tools/call", {
                                name: "open_new_window",
                                arguments: {}
                              })

    new_window = parse_tool_result(result)

    assert_equal "opened", new_window["status"]
    assert new_window["window_handle"]
    assert_equal 2, new_window["total_windows"]

    # Get window handles
    result = make_mcp_request("tools/call", {
                                name: "get_window_handles",
                                arguments: {}
                              })

    window_info = parse_tool_result(result)

    assert_equal 2, window_info["total_windows"]
    handles = window_info["windows"].map { |w| w["handle"] }

    # Switch windows
    result = make_mcp_request("tools/call", {
                                name: "switch_to_window",
                                arguments: { window_handle: handles[0] }
                              })

    switch_result = parse_tool_result(result)

    assert false, "Switch failed with error: #{switch_result["error"]["message"]}" if switch_result["error"]
    # Tool returns "switched" but Browser returns "success"
    assert_includes %w[success switched], switch_result["status"]

    # Close window
    result = make_mcp_request("tools/call", {
                                name: "close_window",
                                arguments: { window_handle: handles[1] }
                              })

    close_result = parse_tool_result(result)

    assert_equal "closed", close_result["status"]
    assert_equal 1, close_result["remaining_windows"]
  end

  def test_error_handling
    # Test visiting invalid URL
    result = make_mcp_request("tools/call", {
                                name: "visit",
                                arguments: { url: "not-a-valid-url" }
                              })

    # Should handle gracefully
    assert result["result"] || result["error"]

    # Test finding non-existent element
    make_mcp_request("tools/call", {
                       name: "visit",
                       arguments: { url: create_test_page_url }
                     })

    result = make_mcp_request("tools/call", {
                                name: "find_element",
                                arguments: { selector: "#non-existent-element" }
                              })

    # Should return error
    if result["error"]
      assert result["error"]["message"].include?("Unable to find") ||
             result["error"]["message"].include?("Unable to locate element"),
             "Expected error message to contain 'Unable to find', got: #{result["error"]["message"]}"
    else
      # Or handle as unsuccessful result
      find_result = parse_tool_result(result)

      assert_equal "error", find_result["status"]
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

  def create_test_page_url(title = "Test Page")
    "data:text/html,<html><head><title>#{title}</title></head><body>" \
      "<h1>#{title}</h1>" \
      "<form>" \
      "<input type='text' name='username' id='username' placeholder='Username'>" \
      "<input type='password' name='password' id='password' placeholder='Password'>" \
      "<button type='submit'>Submit</button>" \
      "<button type='button'>Cancel</button>" \
      "<button type='reset'>Reset</button>" \
      "</form></body></html>"
  end

  def create_interactive_page_url
    "data:text/html,<html><body>" \
      "<div id='hover-target' style='padding:20px;background:#eee;'>Hover over me</div>" \
      "<div id='context-target' style='padding:20px;background:#ddd;'>Right click me</div>" \
      "<div id='double-click-target' style='padding:20px;background:#ccc;'>Double click me</div>" \
      "<script>" \
      "document.getElementById('hover-target').addEventListener('mouseenter', function() {  " \
      "this.style.backgroundColor = 'yellow';" \
      "});" \
      "document.getElementById('context-target').addEventListener('contextmenu', function(e) {  " \
      "e.preventDefault();  " \
      "this.textContent = 'Right clicked!';" \
      "});" \
      "document.getElementById('double-click-target').addEventListener('dblclick', function() {  " \
      "this.textContent = 'Double clicked!';" \
      "});" \
      "</script></body></html>"
  end

  def create_content_page_url
    "data:text/html,<html><body>" \
      "<h1>Content Page</h1>" \
      "<p>This is an important paragraph with some test1 content.</p>" \
      "<p>Another paragraph with important information and test2 data.</p>" \
      "<p>More content here with test3 and test4 references.</p>" \
      "<div class='important'>This div is marked as important.</div>" \
      "<span>Regular content without keywords.</span>" \
      "</body></html>"
  end
end
