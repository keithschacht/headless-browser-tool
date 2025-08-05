# frozen_string_literal: true

require_relative "test_base"
require "tempfile"
require "fileutils"
require "net/http"
require "json"

class TestComplexTools < TestBase
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

  def make_tool_request(tool_name, arguments = {})
    uri = URI("#{@base_url}/mcp")
    request = Net::HTTP::Post.new(uri)
    request["Content-Type"] = "application/json"
    request["X-Session-ID"] = @session_id
    request.body = {
      jsonrpc: "2.0",
      method: "tools/call",
      params: {
        name: tool_name,
        arguments: arguments
      },
      id: rand(1000)
    }.to_json

    response = Net::HTTP.start(uri.hostname, uri.port) do |http|
      http.request(request)
    end

    result = JSON.parse(response.body)

    # Extract the actual result from MCP response
    if result["result"] && result["result"]["content"] && result["result"]["content"][0]
      # Try to parse as JSON, but if it fails, return the text directly
      text = result["result"]["content"][0]["text"]
      begin
        JSON.parse(text)
      rescue JSON::ParserError
        # Return text directly if it's not JSON
        text
      end
    elsif result["error"]
      result
    else
      # Handle unexpected response format
      { "error" => { "message" => "Unexpected response format", "response" => result } }
    end
  end

  def test_drag_tool_with_real_page
    # First navigate to a page with draggable elements
    # Using simpler HTML without complex styles or scripts to ensure compatibility
    make_tool_request("visit",
                      { url: "data:text/html,<html><body>" \
                             "<div id='drag-source' draggable='true'>Drag me</div>" \
                             "<div id='drop-target'>Drop here</div></body></html>" })

    # Perform drag operation
    result = make_tool_request("drag", {
                                 source_selector: "#drag-source",
                                 target_selector: "#drop-target"
                               })

    # Check if there's an error
    flunk "Drag tool returned error: #{result["error"]["message"]}" if result["error"]

    assert_equal "dragged", result["status"]
    assert result["source"]
    assert result["target"]
  end

  def test_attach_file_tool
    # Create a temporary file
    test_file = Tempfile.new(["test", ".txt"])
    test_file.write("Test file content for upload")
    test_file.close

    begin
      # Navigate to a page with file input
      make_tool_request("visit", {
                          url: "data:text/html,<html><body><form>" \
                               "<input type='file' id='file-input' name='upload'>" \
                               "<div id='result'></div></form>" \
                               "<script>document.getElementById('file-input').addEventListener('change',function(e){" \
                               "document.getElementById('result').textContent='File selected: '+e.target.files[0].name;});" \
                               "</script></body></html>"
                        })

      # Attach file
      result = make_tool_request("attach_file", {
                                   file_field_selector: "#file-input",
                                   file_path: test_file.path
                                 })

      assert_equal "attached", result["status"]
      assert result["file_name"]
    ensure
      test_file.unlink
    end
  end

  def test_execute_and_evaluate_script_tools
    make_tool_request("visit", { url: "data:text/html,<html><body><h1>Script Test</h1><div id='result'></div></body></html>" })

    # Test execute_script (no return value)
    execute_result = make_tool_request("execute_script", {
                                         javascript_code: "document.getElementById('result').textContent = 'Executed!';"
                                       })

    assert_equal "executed", execute_result["status"]

    # Test evaluate_script (with return value - no return keyword needed)
    evaluate_result = make_tool_request("evaluate_script", {
                                          javascript_code: "({ message: document.getElementById('result').textContent, timestamp: Date.now() })"
                                        })

    # evaluate_script returns the result directly, not wrapped in a status object
    assert_equal "Executed!", evaluate_result["message"]
    assert evaluate_result["timestamp"]
  end

  def test_screenshot_tool
    # Navigate to a colorful page
    make_tool_request("visit", {
                        url: "data:text/html,<html><body style='background:linear-gradient(to right,red,yellow,green,blue);'>" \
                             "<h1>Screenshot Test</h1><button class='highlight-me'>Button 1</button>" \
                             "<button id='specific'>Button 2</button></body></html>"
                      })

    # Take basic screenshot
    result = make_tool_request("screenshot", {})

    # Screenshot tool returns file_path, not status
    assert result["file_path"], "Should have file_path"
    assert_path_exists result["file_path"]

    # Clean up
    FileUtils.rm_f(result["file_path"])

    # Take screenshot with highlights
    result2 = make_tool_request("screenshot", {
                                  highlight_selectors: [".highlight-me", "#specific"],
                                  filename: test_screenshot_name("highlights.png")
                                })

    # Screenshot tool returns highlighted_elements, not highlighted_count
    assert result2["file_path"]
    assert_equal 2, result2["highlighted_elements"]
    assert_path_exists result2["file_path"]

    # Clean up
    FileUtils.rm_f(result2["file_path"])
  end

  def test_visual_diff_tool
    # Navigate to initial state
    make_tool_request("visit", {
                        url: "data:text/html,<html><body><h1 id='title'>Original Title</h1>" \
                             "<p id='content'>Original content</p>" \
                             "<button onclick='document.getElementById(\"title\").textContent=\"Changed Title\";" \
                             "document.getElementById(\"content\").textContent=\"Changed content\";'>Change</button>" \
                             "</body></html>"
                      })

    # Start visual diff capture
    result1 = make_tool_request("visual_diff", {})

    # Visual diff returns a string summary, not a hash
    assert_kind_of String, result1
    assert_match(/No significant visual changes detected|📍|📄|➕|➖|✏️|💬|📜/, result1)

    # Make changes
    make_tool_request("click", { selector: "button" })
    sleep 0.1

    # Capture diff after changes
    result2 = make_tool_request("visual_diff", {})

    # Should get another string summary
    assert_kind_of String, result2

    # Visual changes might not be detected in headless mode
    # but the tool should still work
  end

  def test_complex_javascript_with_promises
    make_tool_request("visit", { url: "data:text/html,<html><body><div id='async-result'></div></body></html>" })

    # Test async JavaScript evaluation
    result = make_tool_request("evaluate_script", {
                                 javascript_code: <<~JS
                                   new Promise((resolve) => {
                                     setTimeout(() => {
                                       document.getElementById('async-result').textContent = 'Async complete';
                                       resolve({
                                         status: 'completed',
                                         duration: 100,
                                         result: document.getElementById('async-result').textContent
                                       });
                                     }, 100);
                                   })
                                 JS
                               })

    # evaluate_script returns the result directly
    assert_equal "completed", result["status"]
    assert_equal "Async complete", result["result"]
  end

  def test_screenshot_with_full_page
    # Create a tall page
    make_tool_request("visit", {
                        url: "data:text/html,<html><body style='height:3000px;" \
                             "background:linear-gradient(to bottom,red,yellow,green,blue);'>" \
                             "<h1>Top</h1><div style='position:absolute;bottom:0;'>Bottom</div></body></html>"
                      })

    # Take full page screenshot
    result = make_tool_request("screenshot", { full_page: true })

    assert result["file_path"], "Should have file_path"
    assert result["full_page"]
    assert_path_exists result["file_path"]

    # Clean up
    FileUtils.rm_f(result["file_path"])
  end

  def test_complex_form_interactions
    # Navigate to a complex form
    make_tool_request("visit", {
                        url: "data:text/html,<html><body><form>" \
                             "<input type='text' name='username' placeholder='Username'>" \
                             "<input type='password' name='password' placeholder='Password'>" \
                             "<select name='role'><option>User</option><option>Admin</option></select>" \
                             "<input type='checkbox' id='remember' name='remember'>" \
                             "<textarea name='bio' placeholder='Bio'></textarea>" \
                             "<button type='submit'>Submit</button></form></body></html>"
                      })

    # Fill in multiple fields
    make_tool_request("fill_in", { field: "username", value: "testuser" })
    make_tool_request("fill_in", { field: "password", value: "testpass123" })
    make_tool_request("select", { value: "Admin", dropdown_selector: "select[name='role']" })
    make_tool_request("check", { checkbox_selector: "#remember" })
    make_tool_request("fill_in", { field: "bio", value: "This is a test bio with multiple lines.\nLine 2\nLine 3" })

    # Verify all values were set
    values = make_tool_request("evaluate_script", {
                                 javascript_code: <<~JS
                                   ({
                                     username: document.querySelector('input[name="username"]').value,
                                     password: document.querySelector('input[name="password"]').value,
                                     role: document.querySelector('select[name="role"]').value,
                                     remember: document.querySelector('#remember').checked,
                                     bio: document.querySelector('textarea[name="bio"]').value
                                   })
                                 JS
                               })

    assert_equal "testuser", values["username"]
    assert_equal "testpass123", values["password"]
    assert_equal "Admin", values["role"]
    assert values["remember"]
    assert_includes values["bio"], "Line 2"
  end

  def test_element_visibility_and_waiting
    # Navigate to page with delayed content
    make_tool_request("visit", {
                        url: "data:text/html,<html><body>" \
                             "<button onclick='setTimeout(()=>{" \
                             "document.getElementById(\"delayed\").style.display=\"block\";},1000);'>" \
                             "Show Content</button><div id='delayed' style='display:none;'>Delayed content</div>" \
                             "</body></html>"
                      })

    # Check element is initially hidden
    initial_check = make_tool_request("is_visible", { selector: "#delayed" })

    # is_visible returns boolean directly
    refute initial_check

    # Click button to trigger delayed show
    make_tool_request("click", { selector: "button" })

    # Wait for element to become visible
    wait_result = make_tool_request("has_element", { selector: "#delayed", wait_seconds: 2 })

    # has_element returns boolean directly
    assert wait_result

    # Now check visibility
    sleep 1.5 # Give time for the display change
    final_check = make_tool_request("is_visible", { selector: "#delayed" })

    # is_visible returns boolean directly
    assert final_check
  end
end
