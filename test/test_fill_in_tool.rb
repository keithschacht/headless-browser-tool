# frozen_string_literal: true

require "test_helper"

class TestFillInTool < Minitest::Test
  def test_tool_exists
    assert defined?(HeadlessBrowserTool::Tools::FillInTool)
  end

  def test_tool_inherits_from_base
    assert_operator HeadlessBrowserTool::Tools::FillInTool, :<, HeadlessBrowserTool::Tools::BaseTool
  end

  def test_tool_has_execute_method
    assert HeadlessBrowserTool::Tools::FillInTool.method_defined?(:execute)
  end

  def test_tool_registration
    all_tool_names = HeadlessBrowserTool::Tools::ALL_TOOLS.map(&:tool_name)

    assert_includes all_tool_names, "fill_in"
  end

  def test_fill_in_with_invalid_field_name_should_not_succeed
    # Mock browser that will raise Capybara::ElementNotFound for invalid fields
    mock_browser = Object.new

    # Mock find_element to return nil (field not found during info gathering)
    def mock_browser.find_element(_selector)
      nil
    end

    # Mock the fill_in method to raise an error for invalid field
    def mock_browser.fill_in(field, _value)
      # Simulate Capybara behavior for non-existent field
      raise Capybara::ElementNotFound, "Unable to find field \"#{field}\""
    end

    # Set up the tool
    tool = HeadlessBrowserTool::Tools::FillInTool.new

    # Replace the browser method to return our mock
    def tool.browser
      @mock_browser
    end
    tool.instance_variable_set(:@mock_browser, mock_browser)

    # Now try to fill in an invalid field - this should NOT return success
    result = tool.execute(field: "nonexistent_field_123", value: "test_value")

    # Verify it returns an error status, not success
    assert_equal "error", result[:status], "fill_in should return 'error' status for non-existent field"
    assert_equal "Field not found", result[:error], "Should have 'Field not found' error message"
    assert result[:message].include?("nonexistent_field_123"), "Error message should mention the field name"

    # Verify the structure includes all expected fields
    assert_equal "nonexistent_field_123", result[:field]
    assert_equal "test_value", result[:value]
    assert_equal({}, result[:field_info], "field_info should be empty for non-existent field")
  end
end
