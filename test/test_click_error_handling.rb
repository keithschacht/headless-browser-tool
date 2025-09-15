# frozen_string_literal: true

require "test_helper"

class TestClickErrorHandling < Minitest::Test
  # Test error handling in click tools by mocking just the browser
  # while keeping the actual tool error handling logic intact

  def setup
    # Set server to single session mode to avoid session ID requirement
    HeadlessBrowserTool::Server.instance_variable_set(:@single_session_mode, true)
    @mock_browser = MockBrowserForErrors.new
  end

  def teardown
    # Reset server state
    HeadlessBrowserTool::Server.instance_variable_set(:@single_session_mode, nil)
    HeadlessBrowserTool::Server.instance_variable_set(:@browser_instance, nil)
  end

  def test_click_element_not_found
    tool = HeadlessBrowserTool::Tools::ClickTool.new

    # Mock the browser to return empty array for .all() check
    HeadlessBrowserTool::Server.instance_variable_set(:@browser_instance, @mock_browser)
    @mock_browser.should_return_empty = true

    result = tool.execute(text_or_selector: "#non-existent")

    assert_kind_of Hash, result
    assert_equal "error", result[:status]
    assert_match(/Unable to find.*element/i, result[:error])
    assert_equal "#non-existent", result[:text_or_selector]
  end

  def test_click_ambiguous_selector
    tool = HeadlessBrowserTool::Tools::ClickTool.new

    # Mock the browser to return multiple elements for .all() check
    HeadlessBrowserTool::Server.instance_variable_set(:@browser_instance, @mock_browser)
    @mock_browser.should_return_multiple = true

    result = tool.execute(text_or_selector: ".duplicate")

    assert_kind_of Hash, result
    assert_equal "error", result[:status]
    assert_match(/Ambiguous.*found 3 elements/i, result[:error])
    assert_equal ".duplicate", result[:text_or_selector]
  end

  def test_click_button_not_found
    tool = HeadlessBrowserTool::Tools::ClickButtonTool.new

    # Mock browser to raise ElementNotFound
    HeadlessBrowserTool::Server.instance_variable_set(:@browser_instance, @mock_browser)
    @mock_browser.should_raise = Capybara::ElementNotFound.new("Unable to find button \"Submit\"")

    result = tool.execute(button_text_or_selector: "Submit")

    assert_kind_of Hash, result
    assert_equal "error", result[:status]
    assert_match(/Unable to find button/i, result[:error])
    assert_equal "Submit", result[:button]
  end

  def test_click_disabled_element_not_interactable
    tool = HeadlessBrowserTool::Tools::ClickTool.new

    # First return an element for the .all() check, then raise on click
    HeadlessBrowserTool::Server.instance_variable_set(:@browser_instance, @mock_browser)
    mock_element = MockElement.new(tag_name: "button", text: "Disabled", disabled: true)
    @mock_browser.elements_to_return = [mock_element]
    @mock_browser.should_raise_on_click = Selenium::WebDriver::Error::ElementNotInteractableError.new("element not interactable")

    result = tool.execute(text_or_selector: "#disabled-btn")

    assert_kind_of Hash, result
    assert_equal "error", result[:status]
    assert_match(/not interactable.*may be hidden or disabled/i, result[:error])
    assert_equal "#disabled-btn", result[:text_or_selector]
  end

  def test_click_invalid_selector
    tool = HeadlessBrowserTool::Tools::ClickTool.new

    # Mock browser to raise InvalidSelectorError
    HeadlessBrowserTool::Server.instance_variable_set(:@browser_instance, @mock_browser)
    @mock_browser.should_raise = Selenium::WebDriver::Error::InvalidSelectorError.new("invalid selector")

    result = tool.execute(text_or_selector: "##invalid[[[")

    assert_kind_of Hash, result
    assert_equal "error", result[:status]
    assert_match(/Invalid CSS selector/i, result[:error])
    assert_equal "##invalid[[[", result[:text_or_selector]
  end

  def test_click_generic_error
    tool = HeadlessBrowserTool::Tools::ClickTool.new

    # Mock browser to raise a generic error
    HeadlessBrowserTool::Server.instance_variable_set(:@browser_instance, @mock_browser)
    @mock_browser.should_raise = StandardError.new("Something went wrong")

    result = tool.execute(text_or_selector: "#some-element")

    assert_kind_of Hash, result
    assert_equal "error", result[:status]
    assert_match(/Failed to click element.*Something went wrong/i, result[:error])
    assert_equal "#some-element", result[:text_or_selector]
  end

  def test_click_button_not_interactable
    tool = HeadlessBrowserTool::Tools::ClickButtonTool.new

    # Mock browser to raise ElementNotInteractableError
    HeadlessBrowserTool::Server.instance_variable_set(:@browser_instance, @mock_browser)
    @mock_browser.should_raise = Selenium::WebDriver::Error::ElementNotInteractableError.new("element not interactable")

    result = tool.execute(button_text_or_selector: "#hidden-button")

    assert_kind_of Hash, result
    assert_equal "error", result[:status]
    assert_match(/not interactable.*may be hidden or disabled/i, result[:error])
    assert_equal "#hidden-button", result[:button]
  end

  def test_click_button_invalid_selector
    tool = HeadlessBrowserTool::Tools::ClickButtonTool.new

    # Mock browser to raise InvalidSelectorError
    HeadlessBrowserTool::Server.instance_variable_set(:@browser_instance, @mock_browser)
    @mock_browser.should_raise = Selenium::WebDriver::Error::InvalidSelectorError.new("invalid selector")

    result = tool.execute(button_text_or_selector: "###bad")

    assert_kind_of Hash, result
    assert_equal "error", result[:status]
    assert_match(/Invalid selector/i, result[:error])
    assert_equal "###bad", result[:button]
  end
end

# Mock browser that implements just enough to test error handling
class MockBrowserForErrors
  attr_accessor :should_raise, :should_raise_on_click, :should_raise_on_find_button, :elements_to_return, :should_return_empty,
                :should_return_multiple
  attr_reader :current_url

  def initialize
    @current_url = "http://example.com"
    @elements_to_return = []
  end

  def session
    self # Return self as a mock session
  end

  def windows
    ["window1"] # Non-empty array to indicate browser has windows
  end

  def title
    "Test Page"
  end

  def all(_selector, **options)
    raise should_raise if should_raise

    # For text searches, return empty to force fallback
    return [] if options[:text]

    return [] if should_return_empty

    if should_return_multiple
      # Return 3 mock elements for ambiguous selector test
      return [
        MockElement.new(text: "First"),
        MockElement.new(text: "Second"),
        MockElement.new(text: "Third")
      ]
    end

    # Return configured elements or default single element
    elements_to_return.empty? ? [MockElement.new] : elements_to_return
  end

  def find(_selector)
    raise should_raise if should_raise

    # If we're returning empty, also fail find
    raise Capybara::ElementNotFound if should_return_empty

    elements_to_return.first || MockElement.new
  end

  def find_button(text_or_selector)
    raise should_raise if should_raise
    raise should_raise_on_find_button if should_raise_on_find_button

    # If we're returning empty, also fail find_button
    raise Capybara::ElementNotFound if should_return_empty

    MockElement.new(tag_name: "button", text: text_or_selector)
  end

  def find_link(_text_or_selector)
    raise Capybara::ElementNotFound
  end

  def click(_selector)
    raise should_raise_on_click if should_raise_on_click

    true
  end

  def click_button(_text_or_selector)
    raise should_raise if should_raise
    raise should_raise_on_find_button if should_raise_on_find_button
    raise should_raise_on_click if should_raise_on_click

    true
  end
end

# Minimal mock element
class MockElement
  attr_reader :tag_name, :text

  def initialize(attrs = {})
    @tag_name = attrs[:tag_name] || "div"
    @text = attrs[:text] || "Mock Element"
    @attrs = attrs
  end

  def [](attr)
    @attrs[attr]
  end

  def disabled?
    @attrs[:disabled] || false
  end

  def size
    1
  end

  def strip
    self
  end

  def click
    # Get the browser instance to check if we should raise
    browser = HeadlessBrowserTool::Server.instance_variable_get(:@browser_instance)
    raise browser.should_raise_on_click if browser&.should_raise_on_click

    true
  end
end
