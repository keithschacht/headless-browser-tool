# frozen_string_literal: true

require_relative "test_base"
require "net/http"
require "json"

class TestGetPageAsMarkdown < TestBase
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

  def test_get_page_as_markdown_with_selector
    # Navigate to a page with simple HTML content
    html_content = <<~HTML
      <html>
        <body>
          <div id="header">Header Content</div>
          <div id="test-content">
            <h1>Hello World</h1>
            <p>This is a <strong>test</strong> paragraph.</p>
          </div>
          <div id="footer">Footer Content</div>
        </body>
      </html>
    HTML

    make_mcp_request("tools/call", {
                       name: "visit",
                       arguments: { url: "data:text/html,#{html_content}" }
                     })

    # Get specific element content
    result = make_mcp_request("tools/call", {
                                name: "get_page_as_markdown",
                                arguments: { selector: "#test-content" }
                              })

    parsed_result = parse_tool_result(result)

    # Debug output
    puts "Full result: #{parsed_result.inspect}" if parsed_result.is_a?(Hash) && !parsed_result["status"]

    assert_equal "success", parsed_result["status"]
    assert_equal "#test-content", parsed_result["selector"]
    assert_includes parsed_result["markdown"], "# Hello World"
    assert_includes parsed_result["markdown"], "This is a **test** paragraph."
    # Should not include header/footer
    refute_includes parsed_result["markdown"], "Header Content"
    refute_includes parsed_result["markdown"], "Footer Content"
  end

  def test_get_page_as_markdown_without_selector
    # Navigate to a page with simple HTML content
    html_content = <<~HTML
      <html>
        <body>
          <div id="header">Header Content</div>
          <div id="main">
            <h1>Page Title</h1>
            <p>Main content here.</p>
          </div>
          <div id="footer">Footer Content</div>
        </body>
      </html>
    HTML

    make_mcp_request("tools/call", {
                       name: "visit",
                       arguments: { url: "data:text/html,#{html_content}" }
                     })

    # Get entire page content (no selector)
    result = make_mcp_request("tools/call", {
                                name: "get_page_as_markdown",
                                arguments: {}
                              })

    parsed_result = parse_tool_result(result)

    assert_equal "success", parsed_result["status"]
    assert_nil parsed_result["selector"]
    # Should include all content
    assert_includes parsed_result["markdown"], "Header Content"
    assert_includes parsed_result["markdown"], "# Page Title"
    assert_includes parsed_result["markdown"], "Main content here."
    assert_includes parsed_result["markdown"], "Footer Content"
  end

  def test_get_page_as_markdown_strips_images
    # Navigate to a page with images
    html_content = <<~HTML
      <html>
        <body>
          <div id="content">
            <p>Before image</p>
            <img src="test.jpg" alt="Test Image" />
            <p>After image</p>
            <img src="another.png" alt="Another Image" />
            <p>End</p>
          </div>
        </body>
      </html>
    HTML

    make_mcp_request("tools/call", {
                       name: "visit",
                       arguments: { url: "data:text/html,#{html_content}" }
                     })

    # Get content - images should be stripped
    result = make_mcp_request("tools/call", {
                                name: "get_page_as_markdown",
                                arguments: { selector: "#content" }
                              })

    parsed_result = parse_tool_result(result)

    assert_equal "success", parsed_result["status"]
    assert_includes parsed_result["markdown"], "Before image"
    assert_includes parsed_result["markdown"], "After image"
    assert_includes parsed_result["markdown"], "End"
    # Images should be completely removed
    refute_includes parsed_result["markdown"], "![Test Image]"
    refute_includes parsed_result["markdown"], "![Another Image]"
    refute_includes parsed_result["markdown"], "test.jpg"
    refute_includes parsed_result["markdown"], "another.png"
  end

  def test_get_page_as_markdown_with_amazon_tracking_urls
    # Navigate to a page with Amazon tracking URLs
    html_content = <<~HTML
      <html>
        <body>
          <div id="content">
            <a href="https://aax-us-iad.amazon.com/x/c/SOMETRACKING/https://www.amazon.com/dp/B08N5WRWNW/ref=sr_1_1">Product Link</a>
            <a href="https://aax-us-east.amazon.com/x/c/TRACKING/https://www.amazon.com/gp/product/B08N5WRWNW">Another Product</a>
            <a href="https://www.amazon.com/s?k=toothpaste&ref=nb_sb_noss">Search Link</a>
          </div>
        </body>
      </html>
    HTML

    make_mcp_request("tools/call", {
                       name: "visit",
                       arguments: { url: "data:text/html,#{html_content}" }
                     })

    # Get content - Amazon tracking URLs should be cleaned
    result = make_mcp_request("tools/call", {
                                name: "get_page_as_markdown",
                                arguments: { selector: "#content" }
                              })

    parsed_result = parse_tool_result(result)

    assert_equal "success", parsed_result["status"]
    # Should have cleaned Amazon URLs
    assert_includes parsed_result["markdown"], "[Product Link](https://www.amazon.com/dp/B08N5WRWNW)"
    assert_includes parsed_result["markdown"], "[Another Product](https://www.amazon.com/dp/B08N5WRWNW)"
    assert_includes parsed_result["markdown"], "[Search Link](https://www.amazon.com/s"
    # Should not have tracking URLs
    refute_includes parsed_result["markdown"], "aax-us-iad.amazon.com"
    refute_includes parsed_result["markdown"], "aax-us-east.amazon.com"
    refute_includes parsed_result["markdown"], "ref=sr_1_1"
    refute_includes parsed_result["markdown"], "ref=nb_sb_noss"
  end

  def test_get_page_as_markdown_with_nested_lists
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
                                name: "get_page_as_markdown",
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

  def test_get_page_as_markdown_with_table
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
                                name: "get_page_as_markdown",
                                arguments: { selector: "#table-content" }
                              })

    parsed_result = parse_tool_result(result)

    assert_equal "success", parsed_result["status"]
    # ReverseMarkdown converts tables to pipe-separated format
    assert_includes parsed_result["markdown"], "| Name | Age |"
    assert_includes parsed_result["markdown"], "| John | 25 |"
    assert_includes parsed_result["markdown"], "| Jane | 30 |"
  end

  def test_get_page_as_markdown_element_not_found
    # Navigate to a simple page
    make_mcp_request("tools/call", {
                       name: "visit",
                       arguments: { url: "data:text/html,<html><body><div>Test</div></body></html>" }
                     })

    # Try to get content of non-existent element
    result = make_mcp_request("tools/call", {
                                name: "get_page_as_markdown",
                                arguments: { selector: "#non-existent" }
                              })

    parsed_result = parse_tool_result(result)

    # Should get an error
    assert parsed_result["error"]
  end
end
