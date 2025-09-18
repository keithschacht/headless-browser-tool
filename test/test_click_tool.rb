# frozen_string_literal: true

require "test_helper"

class TestClickTool < Minitest::Test
  def test_tool_exists
    assert defined?(HeadlessBrowserTool::Tools::ClickTool)
  end

  def test_tool_inherits_from_base
    assert_operator HeadlessBrowserTool::Tools::ClickTool, :<, HeadlessBrowserTool::Tools::BaseTool
  end

  def test_tool_has_execute_method
    assert HeadlessBrowserTool::Tools::ClickTool.method_defined?(:execute)
  end

  def test_tool_registration
    all_tool_names = HeadlessBrowserTool::Tools::ALL_TOOLS.map(&:tool_name)

    assert_includes all_tool_names, "click"
  end

  def test_ambiguous_selector_without_index_returns_error
    # Case 1: Ambiguous selector with no index gives nice error message
    tool = HeadlessBrowserTool::Tools::ClickTool.new

    # Set server to single session mode to avoid session ID requirement
    HeadlessBrowserTool::Server.instance_variable_set(:@single_session_mode, true)

    # Create mock browser that returns multiple elements
    mock_browser = MockBrowserForClick.new
    mock_browser.elements_to_return = [
      MockClickElement.new(text: "First"),
      MockClickElement.new(text: "Second")
    ]

    HeadlessBrowserTool::Server.instance_variable_set(:@browser_instance, mock_browser)

    result = tool.execute(text_or_selector: "#placeOrder")

    assert_equal "error", result[:status]
    assert_equal "Ambiguous text or selector - found 2 elements matching: #placeOrder", result[:error]
    assert_equal "#placeOrder", result[:text_or_selector]
  ensure
    HeadlessBrowserTool::Server.instance_variable_set(:@single_session_mode, nil)
    HeadlessBrowserTool::Server.instance_variable_set(:@browser_instance, nil)
  end

  def test_ambiguous_selector_with_index_clicks_correct_element
    # Case 2: Ambiguous selector with index (e.g., 2) clicks the 3rd option
    tool = HeadlessBrowserTool::Tools::ClickTool.new

    # Set server to single session mode to avoid session ID requirement
    HeadlessBrowserTool::Server.instance_variable_set(:@single_session_mode, true)

    # Create mock browser that returns multiple elements
    mock_browser = MockBrowserForClick.new
    mock_browser.elements_to_return = [
      MockClickElement.new(text: "First Button", tag_name: "button"),
      MockClickElement.new(text: "Second Button", tag_name: "button"),
      MockClickElement.new(text: "Third Button", tag_name: "button", should_be_clicked: true)
    ]

    HeadlessBrowserTool::Server.instance_variable_set(:@browser_instance, mock_browser)

    result = tool.execute(text_or_selector: "#placeOrder", index: 2)

    assert_equal "success", result[:status], "Should have status: 'success'"
    assert_equal "#placeOrder", result[:text_or_selector]
    assert_equal 2, result[:index]
    assert_equal "button", result[:element][:tag_name]
    assert_equal "Third Button", result[:element][:text]
    assert mock_browser.elements_to_return[2].was_clicked, "Third element should have been clicked"
  ensure
    HeadlessBrowserTool::Server.instance_variable_set(:@single_session_mode, nil)
    HeadlessBrowserTool::Server.instance_variable_set(:@browser_instance, nil)
  end

  def test_unambiguous_selector_with_invalid_index_returns_error
    # Case 3: Unambiguous selector with index other than 0 returns error
    tool = HeadlessBrowserTool::Tools::ClickTool.new

    # Set server to single session mode to avoid session ID requirement
    HeadlessBrowserTool::Server.instance_variable_set(:@single_session_mode, true)

    # Create mock browser that returns single element
    mock_browser = MockBrowserForClick.new
    mock_browser.elements_to_return = [
      MockClickElement.new(text: "Submit", tag_name: "button")
    ]

    HeadlessBrowserTool::Server.instance_variable_set(:@browser_instance, mock_browser)

    result = tool.execute(text_or_selector: "#submit", index: 2)

    assert_equal "error", result[:status]
    assert_equal "Invalid index 2 for 1 elements matching: #submit", result[:error]
    assert_equal "#submit", result[:text_or_selector]
    assert_equal 2, result[:index]
  ensure
    HeadlessBrowserTool::Server.instance_variable_set(:@single_session_mode, nil)
    HeadlessBrowserTool::Server.instance_variable_set(:@browser_instance, nil)
  end

  def test_unambiguous_selector_with_index_zero_clicks_element
    # Single element with index 0 should work fine
    tool = HeadlessBrowserTool::Tools::ClickTool.new

    # Set server to single session mode to avoid session ID requirement
    HeadlessBrowserTool::Server.instance_variable_set(:@single_session_mode, true)

    # Create mock browser that returns single element
    mock_browser = MockBrowserForClick.new
    mock_browser.elements_to_return = [
      MockClickElement.new(text: "Submit", tag_name: "button", should_be_clicked: true)
    ]

    HeadlessBrowserTool::Server.instance_variable_set(:@browser_instance, mock_browser)

    result = tool.execute(text_or_selector: "#submit", index: 0)

    assert_equal "success", result[:status], "Should have status: 'success'"
    assert_equal "#submit", result[:text_or_selector]
    assert_nil result[:index] # Index should not be included when only one element
    assert_equal "button", result[:element][:tag_name]
    assert_equal "Submit", result[:element][:text]
    assert mock_browser.elements_to_return[0].was_clicked, "Single element should have been clicked"
  ensure
    HeadlessBrowserTool::Server.instance_variable_set(:@single_session_mode, nil)
    HeadlessBrowserTool::Server.instance_variable_set(:@browser_instance, nil)
  end

  def test_unambiguous_selector_with_index_one_returns_error
    # Single element with index 1 should return error
    tool = HeadlessBrowserTool::Tools::ClickTool.new

    # Set server to single session mode to avoid session ID requirement
    HeadlessBrowserTool::Server.instance_variable_set(:@single_session_mode, true)

    # Create mock browser that returns single element
    mock_browser = MockBrowserForClick.new
    mock_browser.elements_to_return = [
      MockClickElement.new(text: "Only Button", tag_name: "button")
    ]

    HeadlessBrowserTool::Server.instance_variable_set(:@browser_instance, mock_browser)

    result = tool.execute(text_or_selector: ".btn", index: 1)

    assert_equal "error", result[:status]
    assert_equal "Invalid index 1 for 1 elements matching: .btn", result[:error]
    assert_equal ".btn", result[:text_or_selector]
    assert_equal 1, result[:index]
  ensure
    HeadlessBrowserTool::Server.instance_variable_set(:@single_session_mode, nil)
    HeadlessBrowserTool::Server.instance_variable_set(:@browser_instance, nil)
  end

  def test_invalid_index_returns_error
    # Test that invalid index returns an error
    tool = HeadlessBrowserTool::Tools::ClickTool.new

    # Set server to single session mode to avoid session ID requirement
    HeadlessBrowserTool::Server.instance_variable_set(:@single_session_mode, true)

    # Create mock browser that returns two elements
    mock_browser = MockBrowserForClick.new
    mock_browser.elements_to_return = [
      MockClickElement.new(text: "First"),
      MockClickElement.new(text: "Second")
    ]

    HeadlessBrowserTool::Server.instance_variable_set(:@browser_instance, mock_browser)

    result = tool.execute(text_or_selector: ".btn", index: 5)

    assert_equal "error", result[:status]
    assert_equal "Invalid index 5 for 2 elements matching: .btn", result[:error]
    assert_equal ".btn", result[:text_or_selector]
    assert_equal 5, result[:index]
  ensure
    HeadlessBrowserTool::Server.instance_variable_set(:@single_session_mode, nil)
    HeadlessBrowserTool::Server.instance_variable_set(:@browser_instance, nil)
  end

  def test_negative_index_returns_error
    # Test that negative index returns an error
    tool = HeadlessBrowserTool::Tools::ClickTool.new

    # Set server to single session mode to avoid session ID requirement
    HeadlessBrowserTool::Server.instance_variable_set(:@single_session_mode, true)

    # Create mock browser that returns two elements
    mock_browser = MockBrowserForClick.new
    mock_browser.elements_to_return = [
      MockClickElement.new(text: "First"),
      MockClickElement.new(text: "Second")
    ]

    HeadlessBrowserTool::Server.instance_variable_set(:@browser_instance, mock_browser)

    result = tool.execute(text_or_selector: ".btn", index: -1)

    assert_equal "error", result[:status]
    assert_equal "Invalid index -1 for 2 elements matching: .btn", result[:error]
  ensure
    HeadlessBrowserTool::Server.instance_variable_set(:@single_session_mode, nil)
    HeadlessBrowserTool::Server.instance_variable_set(:@browser_instance, nil)
  end

  def test_single_element_clicks_successfully
    # Test normal click on single element
    tool = HeadlessBrowserTool::Tools::ClickTool.new

    # Set server to single session mode to avoid session ID requirement
    HeadlessBrowserTool::Server.instance_variable_set(:@single_session_mode, true)

    # Create mock browser that returns single element
    mock_browser = MockBrowserForClick.new
    mock_browser.elements_to_return = [
      MockClickElement.new(text: "Click Me", tag_name: "a", should_be_clicked: true)
    ]
    mock_browser.navigation_change = true

    HeadlessBrowserTool::Server.instance_variable_set(:@browser_instance, mock_browser)

    result = tool.execute(text_or_selector: "a.link")

    assert_equal "success", result[:status], "Should have status: 'success'"
    assert_equal "a.link", result[:text_or_selector]
    assert_nil result[:index]
    assert_equal "a", result[:element][:tag_name]
    assert_equal "Click Me", result[:element][:text]
    assert_equal "https://example.com/before", result[:navigation][:url_before]
    assert_equal "https://example.com/after", result[:navigation][:url_after]
    assert result[:navigation][:navigated]
  ensure
    HeadlessBrowserTool::Server.instance_variable_set(:@single_session_mode, nil)
    HeadlessBrowserTool::Server.instance_variable_set(:@browser_instance, nil)
  end

  def test_click_by_button_text
    # Test clicking by button text (not CSS selector)
    tool = HeadlessBrowserTool::Tools::ClickTool.new

    HeadlessBrowserTool::Server.instance_variable_set(:@single_session_mode, true)

    mock_browser = MockBrowserForClick.new
    mock_browser.should_find_button = MockClickElement.new(text: "Submit", tag_name: "button", should_be_clicked: true)

    HeadlessBrowserTool::Server.instance_variable_set(:@browser_instance, mock_browser)

    result = tool.execute(text_or_selector: "Submit")

    assert_equal "success", result[:status]
    assert_equal "button_text", result[:strategy]
    assert_equal "button", result[:element][:tag_name]
    assert_equal "Submit", result[:element][:text]
  ensure
    HeadlessBrowserTool::Server.instance_variable_set(:@single_session_mode, nil)
    HeadlessBrowserTool::Server.instance_variable_set(:@browser_instance, nil)
  end

  def test_click_by_link_text
    # Test clicking by link text (not CSS selector)
    tool = HeadlessBrowserTool::Tools::ClickTool.new

    HeadlessBrowserTool::Server.instance_variable_set(:@single_session_mode, true)

    mock_browser = MockBrowserForClick.new
    mock_browser.should_find_link = MockClickElement.new(text: "Learn More", tag_name: "a", should_be_clicked: true)

    HeadlessBrowserTool::Server.instance_variable_set(:@browser_instance, mock_browser)

    result = tool.execute(text_or_selector: "Learn More")

    assert_equal "success", result[:status]
    assert_equal "link_text", result[:strategy]
    assert_equal "a", result[:element][:tag_name]
    assert_equal "Learn More", result[:element][:text]
  ensure
    HeadlessBrowserTool::Server.instance_variable_set(:@single_session_mode, nil)
    HeadlessBrowserTool::Server.instance_variable_set(:@browser_instance, nil)
  end

  def test_click_text_in_clickable_element
    # Test clicking text found in a clickable element (not button or link)
    tool = HeadlessBrowserTool::Tools::ClickTool.new

    HeadlessBrowserTool::Server.instance_variable_set(:@single_session_mode, true)

    mock_browser = MockBrowserForClick.new
    # Return element when searching for clickable elements with text
    mock_browser.text_search_result = [
      MockClickElement.new(text: "Add to Cart", tag_name: "div", attributes: { role: "button" }, should_be_clicked: true)
    ]

    HeadlessBrowserTool::Server.instance_variable_set(:@browser_instance, mock_browser)

    result = tool.execute(text_or_selector: "Add to Cart")

    assert_equal "success", result[:status]
    assert_equal "text_in_clickable", result[:strategy]
    assert_equal "div", result[:element][:tag_name]
    assert_equal "Add to Cart", result[:element][:text]
  ensure
    HeadlessBrowserTool::Server.instance_variable_set(:@single_session_mode, nil)
    HeadlessBrowserTool::Server.instance_variable_set(:@browser_instance, nil)
  end

  def test_strategy_preference_order
    # Test that button_text is preferred over link_text when both exist
    tool = HeadlessBrowserTool::Tools::ClickTool.new

    HeadlessBrowserTool::Server.instance_variable_set(:@single_session_mode, true)

    mock_browser = MockBrowserForClick.new
    # Both button and link exist with same text
    mock_browser.should_find_button = MockClickElement.new(text: "Click Me", tag_name: "button", should_be_clicked: true)
    mock_browser.should_find_link = MockClickElement.new(text: "Click Me", tag_name: "a")

    HeadlessBrowserTool::Server.instance_variable_set(:@browser_instance, mock_browser)

    result = tool.execute(text_or_selector: "Click Me")

    assert_equal "success", result[:status]
    assert_equal "button_text", result[:strategy], "Should prefer button over link"
    assert_equal "button", result[:element][:tag_name]
  ensure
    HeadlessBrowserTool::Server.instance_variable_set(:@single_session_mode, nil)
    HeadlessBrowserTool::Server.instance_variable_set(:@browser_instance, nil)
  end

  def test_multiple_exact_text_matches_with_partial_matches
    # Test handling of multiple exact matches mixed with partial matches
    tool = HeadlessBrowserTool::Tools::ClickTool.new

    HeadlessBrowserTool::Server.instance_variable_set(:@single_session_mode, true)

    mock_browser = MockBrowserForClick.new
    # Return multiple elements: 2 exact "Submit" and 2 partial matches
    mock_browser.text_search_result = [
      MockClickElement.new(text: "Submit", tag_name: "button"),
      MockClickElement.new(text: "Submit Form", tag_name: "button"),
      MockClickElement.new(text: "Submit", tag_name: "button"),
      MockClickElement.new(text: "Submit Order", tag_name: "button")
    ]

    HeadlessBrowserTool::Server.instance_variable_set(:@browser_instance, mock_browser)

    result = tool.execute(text_or_selector: "Submit")

    # Should return error with all matches listed
    assert_equal "error", result[:status]
    assert_match(/Found 4 clickable elements/i, result[:error])
    assert_equal 4, result[:elements].size

    # Verify the elements are listed with correct indices
    assert_equal 0, result[:elements][0][:index]
    assert_equal "Submit", result[:elements][0][:text]
    assert_equal 1, result[:elements][1][:index]
    assert_equal "Submit Form", result[:elements][1][:text]
    assert_equal 2, result[:elements][2][:index]
    assert_equal "Submit", result[:elements][2][:text]
    assert_equal 3, result[:elements][3][:index]
    assert_equal "Submit Order", result[:elements][3][:text]
  ensure
    HeadlessBrowserTool::Server.instance_variable_set(:@single_session_mode, nil)
    HeadlessBrowserTool::Server.instance_variable_set(:@browser_instance, nil)
  end

  def test_full_html_tag_in_error_listings
    # Test that error messages include full HTML opening tags for better differentiation
    tool = HeadlessBrowserTool::Tools::ClickTool.new

    HeadlessBrowserTool::Server.instance_variable_set(:@single_session_mode, true)

    mock_browser = MockBrowserForClick.new
    # Return multiple similar elements with different attributes
    mock_browser.text_search_result = [
      MockClickElement.new(
        text: "Printable Order Summary",
        tag_name: "a",
        attributes: {
          class: "a-link-normal",
          href: "/gp/css/summary/print.html?orderID=113-6370329-4670655&ref=ab_ppx_yo_dt_b_invoice"
        }
      ),
      MockClickElement.new(
        text: "Printable Order Summary",
        tag_name: "a",
        attributes: {
          class: "a-link-emphasis",
          href: "/gp/css/summary/print.html?orderID=113-1234567-8901234&ref=ab_ppx_yo_dt_b_invoice",
          target: "_blank"
        }
      ),
      MockClickElement.new(
        text: "Printable Order Details",
        tag_name: "button",
        attributes: {
          class: "btn btn-primary",
          id: "print-btn",
          onclick: "printOrder()"
        }
      )
    ]

    HeadlessBrowserTool::Server.instance_variable_set(:@browser_instance, mock_browser)

    result = tool.execute(text_or_selector: "Printable Order")

    # Should return error with all matches listed
    assert_equal "error", result[:status]
    assert_equal 3, result[:elements].size

    # Verify the elements include full HTML opening tags
    assert_equal '<a class="a-link-normal" href="/gp/css/summary/print.html?orderID=113-6370329-4670655&ref=ab_ppx_yo_dt_b_invoice">',
                 result[:elements][0][:html_tag]
    expected_tag = '<a class="a-link-emphasis" ' \
                   'href="/gp/css/summary/print.html?orderID=113-1234567-8901234&ref=ab_ppx_yo_dt_b_invoice" ' \
                   'target="_blank">'

    assert_equal expected_tag, result[:elements][1][:html_tag]
    assert_equal '<button class="btn btn-primary" id="print-btn" onclick="printOrder()">',
                 result[:elements][2][:html_tag]

    # Original fields should still be present
    assert_equal "Printable Order Summary", result[:elements][0][:text]
    assert_equal "Printable Order Summary", result[:elements][1][:text]
    assert_equal "Printable Order Details", result[:elements][2][:text]
  ensure
    HeadlessBrowserTool::Server.instance_variable_set(:@single_session_mode, nil)
    HeadlessBrowserTool::Server.instance_variable_set(:@browser_instance, nil)
  end
end

# Mock browser for click tests
class MockBrowserForClick
  attr_accessor :elements_to_return, :navigation_change, :should_find_button, :should_find_link, :text_search_result
  attr_reader :current_url_calls

  def initialize
    @current_url_calls = 0
    @navigation_change = false
    @should_find_button = nil
    @should_find_link = nil
    @text_search_result = []
  end

  def session
    self # Return self as a mock session
  end

  def windows
    ["mock_window"] # Return non-empty array to indicate browser has windows
  end

  def current_url
    @current_url_calls += 1
    if @navigation_change && @current_url_calls > 2
      "https://example.com/after"
    else
      "https://example.com/before"
    end
  end

  def all(_selector, **options)
    # If it's being called with text option, return text search results
    if options[:text]
      @text_search_result || []
    else
      elements_to_return || []
    end
  end

  def find_button(_text_or_selector)
    return @should_find_button if @should_find_button

    raise Capybara::ElementNotFound
  end

  def find_link(_text_or_selector)
    return @should_find_link if @should_find_link

    raise Capybara::ElementNotFound
  end

  def find(_selector)
    raise Capybara::ElementNotFound
  end
end

# Mock element for click tests
class MockClickElement
  attr_reader :tag_name, :text
  attr_accessor :was_clicked

  def initialize(attrs = {})
    @tag_name = attrs[:tag_name] || "div"
    @text = attrs[:text] || "Mock Element"
    @should_be_clicked = attrs[:should_be_clicked] || false
    @was_clicked = false
    @attributes = attrs[:attributes] || {}
  end

  def disabled?
    false
  end

  def click
    @was_clicked = true
  end

  def [](attribute)
    @attributes[attribute]
  end

  def strip
    @text
  end

  def native
    # Mock native element that responds to attribute
    self
  end

  def attribute(name)
    # Return all attributes as HTML string when 'outerHTML' is requested
    if name == "outerHTML"
      attrs_str = @attributes.map { |k, v| %(#{k}="#{v}") }.join(" ")
      attrs_str = " #{attrs_str}" unless attrs_str.empty?
      "<#{@tag_name}#{attrs_str}>#{@text}</#{@tag_name}>"
    else
      @attributes[name.to_sym]
    end
  end
end
