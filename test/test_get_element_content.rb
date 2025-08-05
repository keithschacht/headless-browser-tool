# frozen_string_literal: true

require_relative "test_base"
require "net/http"
require "json"

class TestGetElementContent < TestBase
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

  def test_get_element_content_with_simple_html
    # Navigate to a page with simple HTML content
    html_content = <<~HTML
      <html>
        <body>
          <div id="test-content">
            <h1>Hello World</h1>
            <p>This is a <strong>test</strong> paragraph.</p>
          </div>
        </body>
      </html>
    HTML

    make_mcp_request("tools/call", {
                       name: "visit",
                       arguments: { url: "data:text/html,#{html_content}" }
                     })

    # Get the element content
    result = make_mcp_request("tools/call", {
                                name: "get_element_content",
                                arguments: { selector: "#test-content" }
                              })

    parsed_result = parse_tool_result(result)

    assert_equal "success", parsed_result["status"]
    assert_equal "#test-content", parsed_result["selector"]
    assert_includes parsed_result["markdown"], "# Hello World"
    assert_includes parsed_result["markdown"], "This is a **test** paragraph."
  end

  def test_get_element_content_with_nested_lists
    # Navigate to a page with nested lists
    html_content = <<~HTML
      <html>
        <body>
          <div id="list-content">
            <ul>
              <li>Item 1</li>
              <li>Item 2
                <ul>
                  <li>Nested 2.1</li>
                  <li>Nested 2.2</li>
                </ul>
              </li>
              <li>Item 3</li>
            </ul>
          </div>
        </body>
      </html>
    HTML

    make_mcp_request("tools/call", {
                       name: "visit",
                       arguments: { url: "data:text/html,#{html_content}" }
                     })

    # Get the element content
    result = make_mcp_request("tools/call", {
                                name: "get_element_content",
                                arguments: { selector: "#list-content" }
                              })

    parsed_result = parse_tool_result(result)

    assert_equal "success", parsed_result["status"]
    # ReverseMarkdown uses dashes for lists, not asterisks
    assert_includes parsed_result["markdown"], "- Item 1"
    assert_includes parsed_result["markdown"], "- Item 2"
    assert_includes parsed_result["markdown"], "  - Nested 2.1"
    assert_includes parsed_result["markdown"], "  - Nested 2.2"
    assert_includes parsed_result["markdown"], "- Item 3"
  end

  def test_get_element_content_with_links_and_images
    # Navigate to a page with links and images
    html_content = <<~HTML
      <html>
        <body>
          <div id="rich-content">
            <p>Visit <a href="https://example.com">our website</a> for more info.</p>
            <img src="test.jpg" alt="Test Image" />
            <p>Another <a href="/page">internal link</a>.</p>
          </div>
        </body>
      </html>
    HTML

    make_mcp_request("tools/call", {
                       name: "visit",
                       arguments: { url: "data:text/html,#{html_content}" }
                     })

    # Get the element content
    result = make_mcp_request("tools/call", {
                                name: "get_element_content",
                                arguments: { selector: "#rich-content" }
                              })

    parsed_result = parse_tool_result(result)

    assert_equal "success", parsed_result["status"]
    assert_includes parsed_result["markdown"], "[our website](https://example.com)"
    assert_includes parsed_result["markdown"], "![Test Image](test.jpg)"
    assert_includes parsed_result["markdown"], "[internal link](/page)"
  end

  def test_get_element_content_with_table
    # Navigate to a page with a table
    html_content = <<~HTML
      <html>
        <body>
          <div id="table-content">
            <table>
              <thead>
                <tr>
                  <th>Name</th>
                  <th>Age</th>
                </tr>
              </thead>
              <tbody>
                <tr>
                  <td>John</td>
                  <td>25</td>
                </tr>
                <tr>
                  <td>Jane</td>
                  <td>30</td>
                </tr>
              </tbody>
            </table>
          </div>
        </body>
      </html>
    HTML

    make_mcp_request("tools/call", {
                       name: "visit",
                       arguments: { url: "data:text/html,#{html_content}" }
                     })

    # Get the element content
    result = make_mcp_request("tools/call", {
                                name: "get_element_content",
                                arguments: { selector: "#table-content" }
                              })

    parsed_result = parse_tool_result(result)

    assert_equal "success", parsed_result["status"]
    # ReverseMarkdown converts tables to pipe-separated format
    assert_includes parsed_result["markdown"], "| Name | Age |"
    assert_includes parsed_result["markdown"], "| John | 25 |"
    assert_includes parsed_result["markdown"], "| Jane | 30 |"
  end

  def test_get_element_content_element_not_found
    # Navigate to a simple page
    make_mcp_request("tools/call", {
                       name: "visit",
                       arguments: { url: "data:text/html,<html><body><div>Test</div></body></html>" }
                     })

    # Try to get content of non-existent element
    result = make_mcp_request("tools/call", {
                                name: "get_element_content",
                                arguments: { selector: "#non-existent" }
                              })

    parsed_result = parse_tool_result(result)

    # Should get an error
    assert parsed_result["error"]
  end
end
