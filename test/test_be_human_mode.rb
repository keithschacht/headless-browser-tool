# frozen_string_literal: true

require "test_helper"
require "headless_browser_tool/browser"

class TestBeHumanMode < Minitest::Test
  def setup
    @browser = nil
  end

  def teardown
    @browser&.session&.quit
  rescue StandardError
    # Ignore errors during cleanup
  end

  def test_be_human_mode_initializes_without_error
    # Test initialization doesn't raise errors
    @browser = HeadlessBrowserTool::Browser.new(headless: true, be_human: true)

    assert @browser
  end

  def test_be_human_mode_can_visit_page
    # Test that be_human mode gracefully handles missing selenium/devtools
    @browser = HeadlessBrowserTool::Browser.new(headless: true, be_human: true)

    # Should not raise an error anymore - it should fall back to JS injection
    @browser.visit("https://www.example.com")

    assert_match "Example Domain", @browser.title
  end

  def test_be_human_mode_with_missing_devtools
    # Simulate missing selenium/devtools by stubbing the require
    original_require = Kernel.method(:require)

    Kernel.define_singleton_method(:require) do |name|
      raise LoadError, "cannot load such file -- selenium/devtools" if name == "selenium/devtools"

      original_require.call(name)
    end

    @browser = HeadlessBrowserTool::Browser.new(headless: true, be_human: true)

    # Should handle the missing devtools gracefully
    @browser.visit("https://www.example.com")

    assert_match "Example Domain", @browser.title
  ensure
    # Restore original require method
    Kernel.define_singleton_method(:require, original_require)
  end

  def test_be_mostly_human_mode_works
    # be_mostly_human should work as it doesn't use CDP
    @browser = HeadlessBrowserTool::Browser.new(headless: true, be_mostly_human: true)

    @browser.visit("https://www.example.com")

    assert_match "Example Domain", @browser.title
  end

  def test_regular_mode_works
    # Regular mode should work fine
    @browser = HeadlessBrowserTool::Browser.new(headless: true, be_human: false)

    @browser.visit("https://www.example.com")

    assert_match "Example Domain", @browser.title
  end
end
