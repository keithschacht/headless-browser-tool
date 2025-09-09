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

    markdown = parse_tool_result(result)

    # Should return structured response
    assert_kind_of Hash, markdown
    assert_equal "success", markdown["status"]
    assert_kind_of String, markdown["result"]
    
    content = markdown["result"]
    assert_includes content, "Before image"
    assert_includes content, "After image"
    assert_includes content, "End"
    # Images should be completely removed
    refute_includes content, "![Test Image]"
    refute_includes content, "![Another Image]"
    refute_includes content, "test.jpg"
    refute_includes content, "another.png"
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

    markdown = parse_tool_result(result)

    # Should return structured response
    assert_kind_of Hash, markdown
    assert_equal "success", markdown["status"]
    assert_kind_of String, markdown["result"]
    
    content = markdown["result"]
    # Should have cleaned Amazon URLs
    assert_includes content, "[Product Link](https://www.amazon.com/dp/B08N5WRWNW)"
    assert_includes content, "[Another Product](https://www.amazon.com/dp/B08N5WRWNW)"
    assert_includes content, "[Search Link](https://www.amazon.com/s"
    # Should not have tracking URLs
    refute_includes content, "aax-us-iad.amazon.com"
    refute_includes content, "aax-us-east.amazon.com"
    refute_includes content, "ref=sr_1_1"
    refute_includes content, "ref=nb_sb_noss"
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

    markdown = parse_tool_result(result)

    # Should return structured response
    assert_kind_of Hash, markdown
    assert_equal "success", markdown["status"]
    assert_kind_of String, markdown["result"]
    
    content = markdown["result"]
    # ReverseMarkdown uses dashes for lists, not asterisks
    assert_includes content, "- Item 1"
    assert_includes content, "- Item 2"
    assert_includes content, "  - Nested 2.1"
    assert_includes content, "  - Nested 2.2"
    assert_includes content, "- Item 3"
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

    markdown = parse_tool_result(result)

    # Should return structured response
    assert_kind_of Hash, markdown
    assert_equal "success", markdown["status"]
    assert_kind_of String, markdown["result"]
    
    content = markdown["result"]
    # ReverseMarkdown converts tables to pipe-separated format
    assert_includes content, "| Name | Age |"
    assert_includes content, "| John | 25 |"
    assert_includes content, "| Jane | 30 |"
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

    # Should return error object, not empty string
    refute result["error"]
    markdown = parse_tool_result(result)

    assert_kind_of Hash, markdown
    assert_equal "Element not found", markdown["error"]
    assert_equal "Selector '#non-existent' did not match any elements", markdown["message"]
  end

  def test_get_page_as_markdown_with_non_existent_selector
    # Navigate to a page with content
    html_content = <<~HTML
      <html>
        <body>
          <div id="main">Main Content</div>
          <div class="content">Other Content</div>
        </body>
      </html>
    HTML

    make_mcp_request("tools/call", {
                       name: "visit",
                       arguments: { url: "data:text/html,#{html_content}" }
                     })

    # Try to get content of non-existent selector (like the .sc-buy-box)
    result = make_mcp_request("tools/call", {
                                name: "get_page_as_markdown",
                                arguments: { selector: ".sc-buy-box" }
                              })

    # The tool should handle non-existent selectors gracefully
    # It should return an error object rather than throwing an exception
    refute result["error"], "Tool should not return an MCP-level error for non-existent selector"

    # Should return error object
    markdown = parse_tool_result(result)

    assert_kind_of Hash, markdown
    assert_equal "Element not found", markdown["error"]
    assert_equal "Selector '.sc-buy-box' did not match any elements", markdown["message"]
  end

  def test_get_page_as_markdown_with_large_content
    # Create HTML with very large content (over 1MB when converted to markdown)
    # Each paragraph is about 100 bytes, so we need more to exceed 1MB after conversion
    large_content = (1..15_000).map { |i| "<p>This is paragraph number #{i}. It contains some text to make the content larger.</p>" }.join("\n")
    html_content = <<~HTML
      <html>
        <body>
          <div id="huge-content">
            #{large_content}
          </div>
        </body>
      </html>
    HTML

    make_mcp_request("tools/call", {
                       name: "visit",
                       arguments: { url: "data:text/html,#{html_content}" }
                     })

    # Try to get the large content
    result = make_mcp_request("tools/call", {
                                name: "get_page_as_markdown",
                                arguments: {} # Get entire page to trigger size limit
                              })

    # Should return a structured error response, not throw an exception
    refute result["error"], "Should not return MCP-level error"

    parsed_result = parse_tool_result(result)
    # Check that we got the expected error structure
    assert_kind_of Hash, parsed_result
    assert_equal "Content too large", parsed_result["error"]
    assert_includes parsed_result["message"], "exceeds the safe limit"
    assert_includes parsed_result["message"], "1000000 bytes"
    # Check that preview is provided
    assert parsed_result["truncated_preview"]
    assert_operator parsed_result["truncated_preview"].length, :<=, 10_000
    assert_includes parsed_result["truncated_preview"], "This is paragraph number"
    # Check original size is reported
    assert parsed_result["original_size"]
    assert_operator parsed_result["original_size"], :>, 1_000_000
    # Check suggestions are provided
    assert_kind_of Array, parsed_result["suggestions"]
    assert_operator parsed_result["suggestions"].length, :>, 0
    assert(parsed_result["suggestions"].any? { |s| s.include?("selector") })
  end

  def test_get_page_as_markdown_with_large_content_but_small_selector
    # Create HTML with large content overall, but we'll select a small part
    large_content = (1..10_000).map { |i| "<p>This is paragraph number #{i}. Extra text to make it larger.</p>" }.join("\n")
    html_content = <<~HTML
      <html>
        <body>
          <div id="small-section">
            <h1>Small Section</h1>
            <p>This is a small amount of content that should work fine.</p>
          </div>
          <div id="huge-section">
            #{large_content}
          </div>
        </body>
      </html>
    HTML

    make_mcp_request("tools/call", {
                       name: "visit",
                       arguments: { url: "data:text/html,#{html_content}" }
                     })

    # Get only the small section - should work normally
    result = make_mcp_request("tools/call", {
                                name: "get_page_as_markdown",
                                arguments: { selector: "#small-section" }
                              })

    # Should return normal markdown, not an error
    refute result["error"]
    markdown = parse_tool_result(result)

    # Should return structured response
    assert_kind_of Hash, markdown
    assert_equal "success", markdown["status"]
    assert_kind_of String, markdown["result"]
    
    content = markdown["result"]
    assert_includes content, "# Small Section"
    assert_includes content, "This is a small amount of content"

    # Should not include the large content
    refute_includes content, "paragraph number 100"
  end

  def test_get_page_as_markdown_with_adjacent_spans
    # Test that adjacent spans don't run together without spacing
    html_content = <<~HTML
      <html>
        <body>
          <a href="https://example.com" id="test-link">
            <span class="nav-line-1">Hello, Pari</span>
            <span class="nav-line-2">
              <span class="abnav-accountfor">Account for Schacht Family LLC</span>
              <span class="nav-icon nav-arrow">▼</span>
            </span>
          </a>
          <div id="divs-test">
            <div>First line</div>
            <div>Second line</div>
            <div>Third line</div>
          </div>
        </body>
      </html>
    HTML

    make_mcp_request("tools/call", {
                       name: "visit",
                       arguments: { url: "data:text/html,#{html_content}" }
                     })

    # Test the link with spans
    result = make_mcp_request("tools/call", {
                                name: "get_page_as_markdown",
                                arguments: { selector: "#test-link" }
                              })

    markdown = parse_tool_result(result)
    
    # Should return structured response
    assert_kind_of Hash, markdown
    assert_equal "success", markdown["status"]
    assert_kind_of String, markdown["result"]
    
    content = markdown["result"]
    # Should have proper spacing between span contents
    refute_includes content, "Hello, PariAccount"
    assert_includes content, "Hello, Pari"
    assert_includes content, "Account for Schacht Family LLC"
    
    # Test divs get proper line breaks
    result = make_mcp_request("tools/call", {
                                name: "get_page_as_markdown",
                                arguments: { selector: "#divs-test" }
                              })

    markdown = parse_tool_result(result)
    
    # Should return structured response
    assert_kind_of Hash, markdown
    assert_equal "success", markdown["status"]
    assert_kind_of String, markdown["result"]
    
    content = markdown["result"]
    # Divs should be on separate lines
    refute_includes content, "First lineSecond line"
    refute_includes content, "Second lineThird line"
    assert_includes content, "First line"
    assert_includes content, "Second line"
    assert_includes content, "Third line"
  end

  def test_get_page_as_markdown_with_exactly_1mb_content
    # Create content that's exactly at the 1MB boundary
    # We want the markdown output to be exactly 1,000,000 bytes
    # Account for markdown conversion overhead
    target_size = 999_950 # Slightly under to account for conversion
    base_text = "X" * 100
    num_paragraphs = target_size / 100

    exact_content = (1..num_paragraphs).map { "<p>#{base_text}</p>" }.join("\n")
    html_content = <<~HTML
      <html>
        <body>
          #{exact_content}
        </body>
      </html>
    HTML

    make_mcp_request("tools/call", {
                       name: "visit",
                       arguments: { url: "data:text/html,#{html_content}" }
                     })

    # Get the content
    result = make_mcp_request("tools/call", {
                                name: "get_page_as_markdown",
                                arguments: {}
                              })

    # Should work normally since it's at or just under the limit
    refute result["error"]
    markdown = parse_tool_result(result)

    # Could be either a success response or error hash (if over limit)
    if markdown.is_a?(Hash) && markdown["error"] == "Content too large"
      # If it went slightly over due to markdown conversion, that's ok
      assert_operator markdown["original_size"], :>=, 1_000_000
      assert markdown["truncated_preview"]
    else
      # If it stayed under, should be a structured success response
      assert_kind_of Hash, markdown
      assert_equal "success", markdown["status"]
      assert_kind_of String, markdown["result"]
      assert_includes markdown["result"], "X" * 50 # At least some X's should be there
    end
  end
end
