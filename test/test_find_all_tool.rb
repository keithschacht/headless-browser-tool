# frozen_string_literal: true

require_relative "test_base"

class TestFindAllTool < TestBase
  def setup
    super
    @browser = HeadlessBrowserTool::Browser.new(headless: true, be_human: true)

    # Set up server in single session mode for testing
    HeadlessBrowserTool::Server.instance_variable_set(:@single_session_mode, true)
    HeadlessBrowserTool::Server.instance_variable_set(:@browser_instance, @browser)

    @tool = HeadlessBrowserTool::Tools::FindAllTool.new
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
    assert defined?(HeadlessBrowserTool::Tools::FindAllTool)
  end

  def test_tool_inherits_from_base
    assert_operator HeadlessBrowserTool::Tools::FindAllTool, :<, HeadlessBrowserTool::Tools::BaseTool
  end

  def test_tool_has_execute_method
    assert HeadlessBrowserTool::Tools::FindAllTool.method_defined?(:execute)
  end

  def test_tool_registration
    all_tool_names = HeadlessBrowserTool::Tools::ALL_TOOLS.map(&:tool_name)

    assert_includes all_tool_names, "find_all"
  end

  def test_find_all_with_existing_elements
    html = <<~HTML
      <html>
        <body>
          <div data-csa-c-slot-id="checkout-itemBlockPanel" class="panel1">Panel 1</div>
          <div data-csa-c-slot-id="checkout-itemBlockPanel" class="panel2">Panel 2</div>
          <div id="col-delivery-group">Delivery Group</div>
        </body>
      </html>
    HTML

    @browser.visit "data:text/html,#{html.gsub(/\s+/, " ").strip.gsub("#", "%23")}"

    # Test finding elements with attribute selector
    result = @tool.execute(selector: '[data-csa-c-slot-id="checkout-itemBlockPanel"]')

    assert_equal 2, result[:count], "Should find 2 elements with data-csa-c-slot-id attribute"
    assert_equal 2, result[:elements].size
    assert_equal "div", result[:elements][0][:tag_name]
    assert_includes result[:elements][0][:text], "Panel 1"
    assert_includes result[:elements][1][:text], "Panel 2"

    # Test finding element by ID
    result = @tool.execute(selector: "#col-delivery-group")

    assert_equal 1, result[:count], "Should find 1 element with ID col-delivery-group"
    assert_equal 1, result[:elements].size
    assert_equal "div", result[:elements][0][:tag_name]
    assert_includes result[:elements][0][:text], "Delivery Group"
  end

  def test_find_all_with_no_matching_elements
    html = <<~HTML
      <html>
        <body>
          <div>Some content</div>
        </body>
      </html>
    HTML

    @browser.visit "data:text/html,#{html.gsub(/\s+/, " ").strip.gsub("#", "%23")}"

    result = @tool.execute(selector: ".non-existent-class")

    assert_equal 0, result[:count], "Should return 0 count when no elements match"
    assert_empty result[:elements], "Should return empty array when no elements match"
  end

  def test_find_all_with_complex_selectors
    html = <<~HTML
      <html>
        <body>
          <div class="container">
            <span class="item">Item 1</span>
            <span class="item">Item 2</span>
          </div>
        </body>
      </html>
    HTML

    @browser.visit "data:text/html,#{html.gsub(/\s+/, " ").strip.gsub("#", "%23")}"

    result = @tool.execute(selector: ".container .item")

    assert_equal 2, result[:count], "Should find nested elements"
    assert_equal 2, result[:elements].size
  end
end
