# frozen_string_literal: true

require "test_helper"

class TestScrollToTool < Minitest::Test
  def setup
    # Set server to single session mode to avoid session ID requirement
    HeadlessBrowserTool::Server.instance_variable_set(:@single_session_mode, true)
    @mock_browser = MockBrowserForScroll.new
  end

  def teardown
    # Reset server state
    HeadlessBrowserTool::Server.instance_variable_set(:@single_session_mode, nil)
    HeadlessBrowserTool::Server.instance_variable_set(:@browser_instance, nil)
  end

  def test_tool_exists
    assert defined?(HeadlessBrowserTool::Tools::ScrollToTool)
  end

  def test_tool_inherits_from_base
    assert_operator HeadlessBrowserTool::Tools::ScrollToTool, :<, HeadlessBrowserTool::Tools::BaseTool
  end

  def test_tool_has_execute_method
    assert HeadlessBrowserTool::Tools::ScrollToTool.method_defined?(:execute)
  end

  def test_tool_registration
    all_tool_names = HeadlessBrowserTool::Tools::ALL_TOOLS.map(&:tool_name)

    assert_includes all_tool_names, "scroll_to"
  end

  def test_successful_scroll
    tool = HeadlessBrowserTool::Tools::ScrollToTool.new
    HeadlessBrowserTool::Server.instance_variable_set(:@browser_instance, @mock_browser)

    result = tool.execute(selector: "#target-element")

    assert_kind_of Hash, result
    assert_equal "scrolled", result[:status]
    assert_equal "#target-element", result[:selector]
    assert_kind_of Hash, result[:element]
    assert_equal "div", result[:element][:tag_name]
    assert_equal "Target Element", result[:element][:text]
    assert_kind_of Hash, result[:scroll]
    assert_equal 0, result[:scroll][:initial_position]
    assert_equal 500, result[:scroll][:final_position]
    assert result[:scroll][:scrolled]
    assert_kind_of Hash, result[:element_position]
    assert_equal 100, result[:element_position][:top]
    assert_equal 50, result[:element_position][:left]
    assert result[:element_position][:in_viewport]
  end

  def test_element_not_found
    tool = HeadlessBrowserTool::Tools::ScrollToTool.new
    HeadlessBrowserTool::Server.instance_variable_set(:@browser_instance, @mock_browser)
    @mock_browser.should_raise = Capybara::ElementNotFound.new("Unable to find element")

    result = tool.execute(selector: "#non-existent")

    assert_kind_of Hash, result
    assert_equal "error", result[:status]
    assert_match(/Unable to find element/i, result[:error])
    assert_equal "#non-existent", result[:selector]
  end

  def test_invalid_selector
    tool = HeadlessBrowserTool::Tools::ScrollToTool.new
    HeadlessBrowserTool::Server.instance_variable_set(:@browser_instance, @mock_browser)
    @mock_browser.should_raise = Selenium::WebDriver::Error::InvalidSelectorError.new("invalid selector")

    result = tool.execute(selector: "##invalid[[[")

    assert_kind_of Hash, result
    assert_equal "error", result[:status]
    assert_match(/Invalid CSS selector/i, result[:error])
    assert_equal "##invalid[[[", result[:selector]
  end

  def test_generic_error
    tool = HeadlessBrowserTool::Tools::ScrollToTool.new
    HeadlessBrowserTool::Server.instance_variable_set(:@browser_instance, @mock_browser)
    @mock_browser.should_raise = StandardError.new("Unexpected error")

    result = tool.execute(selector: "#some-element")

    assert_kind_of Hash, result
    assert_equal "error", result[:status]
    assert_match(/Failed to scroll to element.*Unexpected error/i, result[:error])
    assert_equal "#some-element", result[:selector]
  end
end

# Mock browser for scroll tool testing
class MockBrowserForScroll
  attr_accessor :should_raise
  attr_reader :execute_script_calls, :evaluate_script_calls, :current_url

  def initialize
    @execute_script_calls = []
    @evaluate_script_calls = []
    @current_url = "http://example.com"
  end

  def session
    self
  end

  def find(_selector)
    raise should_raise if should_raise

    MockScrollElement.new
  end

  def execute_script(script, *args)
    @execute_script_calls << { script: script, args: args }
    nil
  end

  def evaluate_script(script, *args)
    @evaluate_script_calls << { script: script, args: args }

    # Return appropriate values based on the script
    case script
    when /window\.pageYOffset/
      # Return different values to simulate scrolling
      @evaluate_script_calls.size == 1 ? 0 : 500
    when /getBoundingClientRect/
      { "top" => 100, "left" => 50 }
    when /window\.innerHeight/
      768
    else
      nil
    end
  end
end

# Mock element for scroll testing
class MockScrollElement
  attr_reader :native

  def initialize
    @native = self
  end

  def tag_name
    "div"
  end

  def text
    "Target Element"
  end

  def [](attr)
    case attr
    when :id then "target-id"
    when :class then "target-class"
    else nil
    end
  end

  def strip
    self
  end
end