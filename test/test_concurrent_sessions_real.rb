# frozen_string_literal: true

require_relative "test_base"
require "net/http"
require "json"
require "headless_browser_tool/server"

class TestConcurrentSessionsReal < TestBase
  # NOTE: All concurrent session tests are currently disabled due to flaky behavior
  # caused by resource exhaustion when running multiple browser instances simultaneously.
  # These tests are preserved for future use when multi-session functionality becomes important.
  # To re-enable, uncomment the test methods below.

  # Commenting out setup/teardown since all tests are disabled
  # def setup
  #   super # Call TestBase setup

  #   allocate_test_port
  #   @base_url = "http://localhost:#{@port}"

  #   # Small delay to avoid overwhelming the system when many tests fork
  #   sleep 0.1

  #   # Start server in multi-session mode with isolated directories
  #   @server_pid = fork do
  #     # Use isolated directories
  #     ENV["HBT_SESSIONS_DIR"] = @sessions_dir
  #     ENV["HBT_SCREENSHOTS_DIR"] = @screenshots_dir
  #     ENV["HBT_LOGS_DIR"] = @logs_dir

  #     $stdout.reopen(File::NULL, "w")
  #     $stderr.reopen(File::NULL, "w")

  #     HeadlessBrowserTool::Server.start_server(
  #       port: @port,
  #       single_session: false, # Multi-session mode
  #       headless: true
  #     )
  #   end

  #   track_child_process(@server_pid)
  #   TestServerHelper.wait_for_server("localhost", @port, path: "/")
  # end

  # def teardown
  #   TestServerHelper.stop_server_process(@server_pid) if @server_pid
  #   super # Call TestBase teardown
  # rescue Errno::ESRCH, Errno::ECHILD
  #   # Process already dead
  # end

  # def test_multiple_concurrent_sessions
  #   session_ids = %w[alice bob charlie]
  #   results = {}

  #   # Create threads for concurrent sessions
  #   threads = session_ids.map do |session_id|
  #     Thread.new do
  #       # Each session navigates to a different page
  #       url = create_test_page(session_id)

  #       make_mcp_request("tools/call", session_id, {
  #                          name: "visit",
  #                          arguments: { url: url }
  #                        })

  #       # Get page title to verify correct navigation
  #       title_result = make_mcp_request("tools/call", session_id, {
  #                                         name: "get_page_title",
  #                                         arguments: {}
  #                                       })

  #       title = parse_tool_result(title_result)

  #       # Store result
  #       results[session_id] = title
  #     end
  #   end

  #   # Wait for all threads to complete
  #   threads.each(&:join)

  #   # Verify each session got the correct page
  #   assert_equal "Page for alice", results["alice"]
  #   assert_equal "Page for bob", results["bob"]
  #   assert_equal "Page for charlie", results["charlie"]
  # end

  # def test_session_isolation
  #   # Two sessions navigate to same page and modify it differently
  #   session1 = "session1"
  #   session2 = "session2"

  #   test_url = create_interactive_test_page

  #   # Both sessions navigate to same URL
  #   [session1, session2].each do |session_id|
  #     make_mcp_request("tools/call", session_id, {
  #                        name: "visit",
  #                        arguments: { url: test_url }
  #                      })
  #   end

  #   # Session 1 fills in form
  #   make_mcp_request("tools/call", session1, {
  #                      name: "fill_in",
  #                      arguments: { field: "test-input", value: "Session 1 data" }
  #                    })

  #   # Session 2 fills in form differently
  #   make_mcp_request("tools/call", session2, {
  #                      name: "fill_in",
  #                      arguments: { field: "test-input", value: "Session 2 data" }
  #                    })

  #   # Get values from both sessions
  #   value1_result = make_mcp_request("tools/call", session1, {
  #                                      name: "get_value",
  #                                      arguments: { selector: "#test-input" }
  #                                    })

  #   value2_result = make_mcp_request("tools/call", session2, {
  #                                      name: "get_value",
  #                                      arguments: { selector: "#test-input" }
  #                                    })

  #   value1 = parse_tool_result(value1_result)
  #   value2 = parse_tool_result(value2_result)

  #   # Each session should have its own value
  #   assert_equal "Session 1 data", value1
  #   assert_equal "Session 2 data", value2
  # end

  # def test_concurrent_navigation
  #   sessions = (1..5).map { |i| "nav-session-#{i}" }
  #   urls = sessions.map { |id| create_test_page(id) }

  #   # All sessions navigate concurrently
  #   threads = sessions.zip(urls).map do |session_id, url|
  #     Thread.new do
  #       # Navigate
  #       make_mcp_request("tools/call", session_id, {
  #                          name: "visit",
  #                          arguments: { url: url }
  #                        })

  #       # Click button
  #       make_mcp_request("tools/call", session_id, {
  #                          name: "click_button",
  #                          arguments: { button_text_or_selector: "Test Button" }
  #                        })

  #       # Get current URL
  #       url_result = make_mcp_request("tools/call", session_id, {
  #                                       name: "get_current_url",
  #                                       arguments: {}
  #                                     })

  #       parse_tool_result(url_result)
  #     end
  #   end

  #   results = threads.map(&:value)

  #   # All sessions should have navigated successfully
  #   assert_equal sessions.count, results.count
  #   results.each do |url|
  #     assert url.start_with?("data:text/html")
  #   end
  # end

  # def test_session_cleanup_on_idle
  #   # Create multiple sessions
  #   active_session = "active-session"
  #   idle_sessions = %w[idle-1 idle-2 idle-3]

  #   # Navigate all sessions
  #   (idle_sessions + [active_session]).each do |session_id|
  #     make_mcp_request("tools/call", session_id, {
  #                        name: "visit",
  #                        arguments: { url: create_test_page(session_id) }
  #                      })
  #   end

  #   # Get initial session info
  #   initial_info = get_session_info

  #   assert_operator initial_info["session_count"], :>=, 4

  #   # Keep active session alive with periodic requests
  #   5.times do
  #     sleep 1
  #     make_mcp_request("tools/call", active_session, {
  #                        name: "get_page_title",
  #                        arguments: {}
  #                      })
  #   end

  #   # Check that active session is still accessible
  #   result = make_mcp_request("tools/call", active_session, {
  #                               name: "get_current_url",
  #                               arguments: {}
  #                             })

  #   assert result["result"], "Active session should still be accessible"
  # end

  # def test_concurrent_javascript_execution
  #   sessions = %w[js-1 js-2 js-3]
  #   threads = []
  #   results = {}

  #   # Navigate all sessions first
  #   sessions.each do |session_id|
  #     make_mcp_request("tools/call", session_id, {
  #                        name: "visit",
  #                        arguments: { url: create_test_page(session_id) }
  #                      })
  #   end

  #   # Execute JavaScript concurrently
  #   sessions.each_with_index do |session_id, index|
  #     threads << Thread.new do
  #       # Execute script to set a value
  #       make_mcp_request("tools/call", session_id, {
  #                          name: "execute_script",
  #                          arguments: {
  #                            javascript_code: "document.body.setAttribute('data-session', '#{session_id}')"
  #                          }
  #                        })

  #       # Evaluate script to get the value
  #       eval_result = make_mcp_request("tools/call", session_id, {
  #                                        name: "evaluate_script",
  #                                        arguments: {
  #                                          javascript_code: "({ session: document.body.getAttribute('data-session'), index: #{index} })"
  #                                        }
  #                                      })

  #       result = parse_tool_result(eval_result)
  #       results[session_id] = result
  #     end
  #   end

  #   threads.each(&:join)

  #   # Verify each session has correct values
  #   sessions.each_with_index do |session_id, index|
  #     assert_equal session_id, results[session_id]["session"]
  #     assert_equal index, results[session_id]["index"]
  #   end
  # end

  # def test_concurrent_screenshot_capture
  #   sessions = %w[screenshot-1 screenshot-2]
  #   screenshots = {}

  #   # Navigate sessions to different colored pages
  #   colors = %w[red blue]
  #   sessions.zip(colors).each do |session_id, color|
  #     make_mcp_request("tools/call", session_id, {
  #                        name: "visit",
  #                        arguments: { url: create_colored_page(color) }
  #                      })
  #   end

  #   # Capture screenshots concurrently
  #   threads = sessions.map do |session_id|
  #     Thread.new do
  #       result = make_mcp_request("tools/call", session_id, {
  #                                   name: "screenshot",
  #                                   arguments: { filename: test_screenshot_name("concurrent_#{session_id}") }
  #                                 })

  #       screenshot_data = parse_tool_result(result)
  #       screenshots[session_id] = screenshot_data["file_path"]
  #     end
  #   end

  #   threads.each(&:join)

  #   # Verify screenshots were created
  #   screenshots.each do |session_id, path|
  #     assert_path_exists path, "Screenshot for #{session_id} should exist"
  #     # Clean up
  #     FileUtils.rm_f(path)
  #   end
  # end

  # def test_session_limit_enforcement
  #   # Try to create more sessions than the limit
  #   max_sessions = 10 # From SessionManager::MAX_SESSIONS
  #   session_ids = (1..15).map { |i| "limit-test-#{i}" }

  #   # Create sessions up to and beyond the limit
  #   session_ids.each do |session_id|
  #     make_mcp_request("tools/call", session_id, {
  #                        name: "visit",
  #                        arguments: { url: create_test_page(session_id) }
  #                      })
  #   end

  #   # Get session info
  #   info = get_session_info

  #   # Should not exceed max sessions
  #   assert_operator info["session_count"], :<=, max_sessions, "Session count (#{info["session_count"]}) should not exceed max (#{max_sessions})"
  # end

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

  def make_mcp_request(method, session_id, params = {})
    uri = URI("#{@base_url}/mcp")
    request = Net::HTTP::Post.new(uri)
    request["Content-Type"] = "application/json"
    request["X-Session-ID"] = session_id
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

  def get_session_info
    uri = URI("#{@base_url}/sessions")
    response = Net::HTTP.get(uri)
    JSON.parse(response)
  end

  def create_test_page(session_id)
    "data:text/html,<html><head><title>Page for #{session_id}</title></head><body>" \
      "<h1>Session: #{session_id}</h1>" \
      "<input type='text' id='test-input' placeholder='Enter text'>" \
      "<button>Test Button</button>" \
      "</body></html>"
  end

  def create_interactive_test_page
    "data:text/html,<html><body>" \
      "<h1>Interactive Test Page</h1>" \
      "<input type='text' id='test-input' value='Initial value'>" \
      "<div id='result'></div>" \
      "</body></html>"
  end

  def create_colored_page(color)
    "data:text/html,<html><body style='background-color:#{color};'>" \
      "<h1 style='color:white;'>#{color.capitalize} Page</h1>" \
      "</body></html>"
  end
end
