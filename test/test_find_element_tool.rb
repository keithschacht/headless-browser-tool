# frozen_string_literal: true

require_relative "test_base"

class TestFindElementTool < TestBase
  def setup
    super
    @browser = HeadlessBrowserTool::Browser.new(headless: true, be_human: true)

    # Set up server in single session mode for testing
    HeadlessBrowserTool::Server.instance_variable_set(:@single_session_mode, true)
    HeadlessBrowserTool::Server.instance_variable_set(:@browser_instance, @browser)

    @tool = HeadlessBrowserTool::Tools::FindElementTool.new
  end

  def teardown
    begin
      @browser = nil
    rescue StandardError
      nil
    end
    super
  end

  def test_tool_exists
    assert defined?(HeadlessBrowserTool::Tools::FindElementTool)
  end

  def test_tool_inherits_from_base
    assert_operator HeadlessBrowserTool::Tools::FindElementTool, :<, HeadlessBrowserTool::Tools::BaseTool
  end

  def test_tool_has_execute_method
    assert HeadlessBrowserTool::Tools::FindElementTool.method_defined?(:execute)
  end

  def test_tool_registration
    all_tool_names = HeadlessBrowserTool::Tools::ALL_TOOLS.map(&:tool_name)

    assert_includes all_tool_names, "find_element"
  end

  def test_find_element_returns_structured_response
    html = <<~HTML
      <html>
        <body>
          <h1 id="main-title" class="header primary">Welcome</h1>
          <div>Some content</div>
        </body>
      </html>
    HTML

    @browser.visit "data:text/html,#{html.gsub(/\s+/, " ").strip.gsub("#", "%23")}"

    result = @tool.execute(selector: "h1")

    assert_kind_of Hash, result, "Should return a hash"
    assert_equal "success", result[:status], "Should have status: success"
    assert_kind_of String, result[:result], "Should have result as string"
    assert_includes result[:result], "Found element: h1", "Result should contain summary line"
    assert_includes result[:result], "<h1", "Result should contain opening HTML tag"
  end

  def test_find_element_with_id_and_class
    html = <<~HTML
      <html>
        <body>
          <button id="submit-btn" class="btn btn-primary" data-action="submit">Submit</button>
        </body>
      </html>
    HTML

    @browser.visit "data:text/html,#{html.gsub(/\s+/, " ").strip.gsub("#", "%23")}"

    result = @tool.execute(selector: "#submit-btn")

    assert_equal "success", result[:status]
    assert_includes result[:result], "Found element: #submit-btn"
    assert_includes result[:result], 'id="submit-btn"', "Should include id attribute"
    assert_includes result[:result], 'class="btn btn-primary"', "Should include class attribute"
    assert_includes result[:result], 'data-action="submit"', "Should include data attributes"
  end

  def test_find_element_with_no_attributes
    html = <<~HTML
      <html>
        <body>
          <p>Simple paragraph</p>
        </body>
      </html>
    HTML

    @browser.visit "data:text/html,#{html.gsub(/\s+/, " ").strip.gsub("#", "%23")}"

    result = @tool.execute(selector: "p")

    assert_equal "success", result[:status]
    assert_includes result[:result], "Found element: p"
    assert_includes result[:result], "<p>", "Should show simple opening tag for element without attributes"
  end

  def test_find_element_shows_only_opening_tag
    html = <<~HTML
      <html>
        <body>
          <div class="container">
            <p>This is a very long paragraph with lots of content that should not be shown in the output</p>
          </div>
        </body>
      </html>
    HTML

    @browser.visit "data:text/html,#{html.gsub(/\s+/, " ").strip.gsub("#", "%23")}"

    result = @tool.execute(selector: ".container")

    assert_equal "success", result[:status]
    assert_includes result[:result], "Found element: .container"
    assert_includes result[:result], '<div class="container">', "Should show opening tag"
    refute_includes result[:result], "</div>", "Should not include closing tag"
    refute_includes result[:result], "This is a very long paragraph", "Should not include inner content"
  end

  def test_find_element_formats_multiline_response
    html = <<~HTML
      <html>
        <body>
          <input type="text" id="username" class="form-control" placeholder="Enter username" required>
        </body>
      </html>
    HTML

    @browser.visit "data:text/html,#{html.gsub(/\s+/, " ").strip.gsub("#", "%23")}"

    result = @tool.execute(selector: "input")

    assert_equal "success", result[:status]

    lines = result[:result].split("\n")

    assert_equal 2, lines.length, "Result should have exactly 2 lines"
    assert_equal "Found element: input", lines[0], "First line should be summary"
    assert_match(/<input/, lines[1], "Second line should be opening HTML tag")
    assert_includes lines[1], 'type="text"'
    assert_includes lines[1], 'id="username"'
  end

  def test_find_element_with_nonexistent_element
    html = <<~HTML
      <html>
        <body>
          <div>Some content</div>
        </body>
      </html>
    HTML

    @browser.visit "data:text/html,#{html.gsub(/\s+/, " ").strip.gsub("#", "%23")}"

    result = @tool.execute(selector: "#non-existent")

    assert_equal "error", result[:status]
    assert_equal "Unable to find element #non-existent", result[:error]
  end
end
