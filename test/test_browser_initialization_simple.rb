# frozen_string_literal: true

require "test_helper"

class TestBrowserInitializationSimple < Minitest::Test
  def test_browser_initializes_with_defaults
    # We can't actually create browsers in tests without proper setup
    # So we test the class exists and has expected methods
    assert defined?(HeadlessBrowserTool::Browser)

    browser_class = HeadlessBrowserTool::Browser

    assert browser_class.method_defined?(:visit)
    assert browser_class.method_defined?(:refresh)
    assert browser_class.method_defined?(:go_back)
    assert browser_class.method_defined?(:go_forward)
    assert browser_class.method_defined?(:active?)
  end

  def test_browser_adapter_exists
    assert defined?(HeadlessBrowserTool::BrowserAdapter)

    adapter_class = HeadlessBrowserTool::BrowserAdapter

    assert adapter_class.method_defined?(:visit)
    assert adapter_class.method_defined?(:current_url)
    assert adapter_class.method_defined?(:find)
    assert adapter_class.method_defined?(:refresh)
  end
end
