# frozen_string_literal: true

require_relative "test_base"
require "net/http"
require "json"

class TestSearchPageTool < TestBase
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

  def test_tool_exists
    assert defined?(HeadlessBrowserTool::Tools::SearchPageTool)
  end

  def test_tool_inherits_from_base
    assert_operator HeadlessBrowserTool::Tools::SearchPageTool, :<, HeadlessBrowserTool::Tools::BaseTool
  end

  def test_tool_has_execute_method
    assert HeadlessBrowserTool::Tools::SearchPageTool.method_defined?(:execute)
  end

  def test_tool_registration
    all_tool_names = HeadlessBrowserTool::Tools::ALL_TOOLS.map(&:tool_name)

    assert_includes all_tool_names, "search_page"
  end

  def test_search_page_with_text
    # Navigate to a page with test content
    test_html = "<html><body><h1>Test Page</h1>" \
                "<p>This is a test paragraph with delivery option text.</p>" \
                "<button>Choose your delivery option</button></body></html>"
    response = make_mcp_request("tools/call", {
                                  name: "visit",
                                  arguments: { url: "data:text/html,#{test_html}" }
                                })

    assert_nil response["error"], "Visit tool should not error"

    # Search for text on the page
    response = make_mcp_request("tools/call", {
                                  name: "search_page",
                                  arguments: { query: "Choose your delivery option", context_lines: 0 }
                                })

    # Should return a result without errors
    assert_nil response["error"], "Search should not error: #{response["error"]}"

    result = parse_tool_result(response)

    assert_kind_of Hash, result, "Result should be a hash"
    assert_predicate result["total_matches"], :positive?, "Should find at least one match"
    assert result["matches"], "Result should have matches array"
    assert result["matches"][0], "Should have at least one match"
    assert_includes result["matches"][0]["line"], "Choose your delivery option"
  end

  def test_search_page_html_fallback
    # Navigate to a page where text is only in attributes (not visible)
    test_html = "<html><body><input type='hidden' value='secret-value-123' />" \
                "<div style='display:none'>hidden text</div></body></html>"
    response = make_mcp_request("tools/call", {
                                  name: "visit",
                                  arguments: { url: "data:text/html,#{test_html}" }
                                })

    assert_nil response["error"], "Visit tool should not error"

    # Search for text that only exists in HTML attributes
    response = make_mcp_request("tools/call", {
                                  name: "search_page",
                                  arguments: { query: "secret-value-123", context_lines: 0 }
                                })

    # The main fix: this should not error with undefined method 'html'
    assert_nil response["error"], "Search should not error: #{response["error"]}"

    result = parse_tool_result(response)

    assert_kind_of Hash, result, "Result should be a hash"
    # When no visible matches, it should fall back to HTML search
    assert_equal 0, result["total_matches"], "Should have no visible text matches"
    # The html_matches should be present when text is found only in HTML attributes
    return unless result["html_matches"]

    assert_kind_of Array, result["html_matches"], "html_matches should be an array"
    assert result["html_matches"].any? { |match| match["value"]&.include?("secret-value-123") }, "Should find the hidden value"
  end
end
