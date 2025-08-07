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

    result = tool.execute(selector: "#placeOrder")

    assert_equal "error", result[:status]
    assert_equal "Ambiguous selector - found 2 elements matching: #placeOrder", result[:error]
    assert_equal "#placeOrder", result[:selector]
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

    result = tool.execute(selector: "#placeOrder", index: 2)

    assert_equal "#placeOrder", result[:selector]
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

    result = tool.execute(selector: "#submit", index: 2)

    assert_equal "error", result[:status]
    assert_equal "Invalid index 2 for 1 elements matching: #submit", result[:error]
    assert_equal "#submit", result[:selector]
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

    result = tool.execute(selector: "#submit", index: 0)

    assert_equal "#submit", result[:selector]
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

    result = tool.execute(selector: ".btn", index: 1)

    assert_equal "error", result[:status]
    assert_equal "Invalid index 1 for 1 elements matching: .btn", result[:error]
    assert_equal ".btn", result[:selector]
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

    result = tool.execute(selector: ".btn", index: 5)

    assert_equal "error", result[:status]
    assert_equal "Invalid index 5 for 2 elements matching: .btn", result[:error]
    assert_equal ".btn", result[:selector]
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

    result = tool.execute(selector: ".btn", index: -1)

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

    result = tool.execute(selector: "a.link")

    assert_equal "a.link", result[:selector]
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
end

# Mock browser for click tests
class MockBrowserForClick
  attr_accessor :elements_to_return, :navigation_change
  attr_reader :current_url_calls

  def initialize
    @current_url_calls = 0
    @navigation_change = false
  end

  def session
    self # Return self as a mock session
  end

  def current_url
    @current_url_calls += 1
    if @navigation_change && @current_url_calls > 2
      "https://example.com/after"
    else
      "https://example.com/before"
    end
  end

  def all(_selector, **_options)
    elements_to_return || []
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
  end

  def disabled?
    false
  end

  def click
    @was_clicked = true
  end
end
