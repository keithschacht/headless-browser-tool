# frozen_string_literal: true

require "test_helper"

class TestClickLinkTool < Minitest::Test
  def test_tool_exists
    assert defined?(HeadlessBrowserTool::Tools::ClickLinkTool)
  end

  def test_tool_inherits_from_base
    assert_operator HeadlessBrowserTool::Tools::ClickLinkTool, :<, HeadlessBrowserTool::Tools::BaseTool
  end

  def test_tool_has_execute_method
    assert HeadlessBrowserTool::Tools::ClickLinkTool.method_defined?(:execute)
  end

  def test_tool_registration
    all_tool_names = HeadlessBrowserTool::Tools::ALL_TOOLS.map(&:tool_name)

    assert_includes all_tool_names, "click_link"
  end

  def test_link_not_found_returns_clean_error
    # Test that when link is not found, it returns a clean error message
    tool = HeadlessBrowserTool::Tools::ClickLinkTool.new

    # Set thread local session_id to avoid multi-session error
    Thread.current[:hbt_session_id] = "test-session"

    # Mock browser behavior
    browser = Minitest::Mock.new
    browser.expect :current_url, "http://example.com/before"
    browser.expect :title, "Before Title"

    # Mock find_link to raise ElementNotFound
    browser.expect :find_link, nil do |selector|
      raise Capybara::ElementNotFound, "Unable to find link \"#{selector}\""
    end

    # Mock find to also raise ElementNotFound (fallback also fails)
    browser.expect :find, nil do |selector|
      raise Capybara::ElementNotFound, "Unable to find css \"#{selector}\""
    end

    # Directly set the browser to bypass session manager logic
    tool.instance_variable_set(:@browser, browser)

    # Patch the browser method to return our mock
    def tool.browser
      @browser
    end

    result = tool.execute(link_text_or_selector: "Not now")

    assert_equal "error", result[:status]
    assert_equal "Unable to find link Not now", result[:error]
    browser.verify
  ensure
    Thread.current[:hbt_session_id] = nil
  end

  def test_returns_success_status
    # This test ensures the tool returns status: 'success' instead of 'clicked'
    tool = HeadlessBrowserTool::Tools::ClickLinkTool.new

    # Set thread local session_id to avoid multi-session error
    Thread.current[:hbt_session_id] = "test-session"

    # Mock browser behavior
    browser = Minitest::Mock.new
    browser.expect :current_url, "http://example.com/before"
    browser.expect :title, "Before Title"
    # Create a struct that acts like an element with the [] method
    element_struct = Struct.new(:text) do
      def [](attr)
        case attr
        when :href then "/path"
        when :target then nil
        end
      end
    end

    browser.expect :find_link, element_struct.new("Link Text"), ["Link Text"]
    browser.expect :click_link, nil, ["Link Text"]
    browser.expect :current_url, "http://example.com/after"
    browser.expect :current_url, "http://example.com/after"
    browser.expect :title, "After Title"

    # Directly set the browser to bypass session manager logic
    tool.instance_variable_set(:@browser, browser)

    # Patch the browser method to return our mock
    def tool.browser
      @browser
    end

    result = tool.execute(link_text_or_selector: "Link Text")

    assert_equal "success", result[:status]
    browser.verify
  ensure
    Thread.current[:hbt_session_id] = nil
  end
end
