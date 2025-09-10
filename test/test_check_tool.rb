# frozen_string_literal: true

require "test_helper"

class TestCheckTool < Minitest::Test
  def test_tool_exists
    assert defined?(HeadlessBrowserTool::Tools::CheckTool)
  end

  def test_tool_inherits_from_base
    assert_operator HeadlessBrowserTool::Tools::CheckTool, :<, HeadlessBrowserTool::Tools::BaseTool
  end

  def test_tool_has_execute_method
    assert HeadlessBrowserTool::Tools::CheckTool.method_defined?(:execute)
  end

  def test_tool_registration
    all_tool_names = HeadlessBrowserTool::Tools::ALL_TOOLS.map(&:tool_name)

    assert_includes all_tool_names, "check"
  end

  def test_element_not_found
    tool = HeadlessBrowserTool::Tools::CheckTool.new
    Thread.current[:hbt_session_id] = "test-session"

    # Mock browser behavior
    browser = Object.new
    def browser.all(selector, visible: true)
      [] if selector == "#nonexistent" && visible
    end

    def tool.browser
      @browser
    end
    tool.instance_variable_set(:@browser, browser)

    result = tool.execute(checkbox_selector: "#nonexistent")

    assert_equal "error", result[:status]
    assert_equal "Element #nonexistent not found", result[:error]
  ensure
    Thread.current[:hbt_session_id] = nil
  end

  def test_element_not_a_checkbox
    tool = HeadlessBrowserTool::Tools::CheckTool.new
    Thread.current[:hbt_session_id] = "test-session"

    # Mock element that's not a checkbox
    element = Object.new

    # Mock browser behavior
    browser = Object.new
    browser.define_singleton_method(:all) do |selector, visible: true|
      [element] if selector == "#not-checkbox" && visible
    end
    browser.define_singleton_method(:evaluate_script) do |script|
      nil if script == "document.querySelector('#not-checkbox').checked"
    end

    def tool.browser
      @browser
    end
    tool.instance_variable_set(:@browser, browser)

    result = tool.execute(checkbox_selector: "#not-checkbox")

    assert_equal "error", result[:status]
    assert_equal "Element #not-checkbox is not a checkbox", result[:error]
  ensure
    Thread.current[:hbt_session_id] = nil
  end

  def test_checkbox_already_checked
    tool = HeadlessBrowserTool::Tools::CheckTool.new
    Thread.current[:hbt_session_id] = "test-session"

    # Mock element
    element = Struct.new(:id, :name, :value, :type) do
      def [](key)
        case key
        when :id then "123"
        when :name then "test-checkbox"
        when :value then "on"
        when :type then "checkbox"
        end
      end
    end.new

    # Mock browser behavior
    browser = Object.new
    browser.define_singleton_method(:all) do |selector, visible: true|
      [element] if selector == "#my-checkbox" && visible
    end
    browser.define_singleton_method(:evaluate_script) do |script|
      true if script == "document.querySelector('#my-checkbox').checked"
    end

    def tool.browser
      @browser
    end
    tool.instance_variable_set(:@browser, browser)

    result = tool.execute(checkbox_selector: "#my-checkbox")

    assert_equal "success", result[:status]
    assert_equal "#my-checkbox", result[:selector]
    assert result[:was_checked]
    assert result[:is_checked]
  ensure
    Thread.current[:hbt_session_id] = nil
  end

  def test_checkbox_needs_checking_via_click
    tool = HeadlessBrowserTool::Tools::CheckTool.new
    Thread.current[:hbt_session_id] = "test-session"

    # Mock element
    element = Struct.new(:id, :name, :value, :type, :clicked) do
      def [](key)
        case key
        when :id then "123"
        when :name then "test-checkbox"
        when :value then "on"
        when :type then "checkbox"
        end
      end

      def click
        self.clicked = true
      end
    end.new

    # Mock browser behavior
    browser = Object.new
    call_count = 0
    browser.define_singleton_method(:all) do |selector, visible: true|
      [element] if selector == "#my-checkbox" && visible
    end
    browser.define_singleton_method(:evaluate_script) do |script|
      return unless script == "document.querySelector('#my-checkbox').checked"

      call_count += 1
      call_count != 1
    end

    def tool.browser
      @browser
    end
    tool.instance_variable_set(:@browser, browser)

    result = tool.execute(checkbox_selector: "#my-checkbox")

    assert_equal "success", result[:status]
    assert_equal "#my-checkbox", result[:selector]
    refute result[:was_checked]
    assert result[:is_checked]
  ensure
    Thread.current[:hbt_session_id] = nil
  end

  def test_checkbox_click_failed_to_check
    tool = HeadlessBrowserTool::Tools::CheckTool.new
    Thread.current[:hbt_session_id] = "test-session"

    # Mock element
    element = Struct.new(:clicked) do
      def click
        self.clicked = true
      end
    end.new

    # Mock browser behavior
    browser = Object.new
    browser.define_singleton_method(:all) do |selector, visible: true|
      [element] if selector == "#my-checkbox" && visible
    end
    browser.define_singleton_method(:evaluate_script) do |script|
      false if script == "document.querySelector('#my-checkbox').checked"
    end

    def tool.browser
      @browser
    end
    tool.instance_variable_set(:@browser, browser)

    result = tool.execute(checkbox_selector: "#my-checkbox")

    assert_equal "error", result[:status]
    assert_equal "Clicked element #my-checkbox but it did not change to checked state", result[:error]
  ensure
    Thread.current[:hbt_session_id] = nil
  end

  def test_checkbox_with_index
    tool = HeadlessBrowserTool::Tools::CheckTool.new
    Thread.current[:hbt_session_id] = "test-session"

    # Mock elements
    element1 = Object.new
    element2 = Struct.new(:id, :name, :value, :type, :clicked) do
      def [](key)
        case key
        when :id then "456"
        when :name then "test-checkbox-2"
        when :value then "on"
        when :type then "checkbox"
        end
      end

      def click
        self.clicked = true
      end
    end.new

    # Mock browser behavior
    browser = Object.new
    call_count = 0
    browser.define_singleton_method(:all) do |selector, visible: true|
      [element1, element2] if selector == ".checkbox" && visible
    end
    browser.define_singleton_method(:evaluate_script) do |script|
      return unless script == "document.querySelectorAll('.checkbox')[1].checked"

      call_count += 1
      call_count != 1
    end

    def tool.browser
      @browser
    end
    tool.instance_variable_set(:@browser, browser)

    result = tool.execute(checkbox_selector: ".checkbox", index: 1)

    assert_equal "success", result[:status]
    assert_equal ".checkbox", result[:selector]
    assert_equal 1, result[:index]
    refute result[:was_checked]
    assert result[:is_checked]
  ensure
    Thread.current[:hbt_session_id] = nil
  end

  def test_ambiguous_selector_without_index
    tool = HeadlessBrowserTool::Tools::CheckTool.new
    Thread.current[:hbt_session_id] = "test-session"

    # Mock elements
    element1 = Object.new
    element2 = Object.new

    # Mock browser behavior
    browser = Object.new
    browser.define_singleton_method(:all) do |selector, visible: true|
      [element1, element2] if selector == ".checkbox" && visible
    end

    def tool.browser
      @browser
    end
    tool.instance_variable_set(:@browser, browser)

    result = tool.execute(checkbox_selector: ".checkbox")

    assert_equal "error", result[:status]
    assert_equal "Ambiguous selector - found 2 elements matching: .checkbox", result[:error]
  ensure
    Thread.current[:hbt_session_id] = nil
  end

  def test_invalid_index
    tool = HeadlessBrowserTool::Tools::CheckTool.new
    Thread.current[:hbt_session_id] = "test-session"

    # Mock elements
    element1 = Object.new
    element2 = Object.new

    # Mock browser behavior
    browser = Object.new
    browser.define_singleton_method(:all) do |selector, visible: true|
      [element1, element2] if selector == ".checkbox" && visible
    end

    def tool.browser
      @browser
    end
    tool.instance_variable_set(:@browser, browser)

    result = tool.execute(checkbox_selector: ".checkbox", index: 5)

    assert_equal "error", result[:status]
    assert_equal "Invalid index 5 for 2 elements matching: .checkbox", result[:error]
  ensure
    Thread.current[:hbt_session_id] = nil
  end
end
