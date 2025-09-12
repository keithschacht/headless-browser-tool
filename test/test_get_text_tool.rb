# frozen_string_literal: true

require "test_helper"
require "minitest/mock"

class TestGetTextTool < Minitest::Test
  def test_tool_exists
    assert defined?(HeadlessBrowserTool::Tools::GetTextTool)
  end

  def test_tool_inherits_from_base
    assert_operator HeadlessBrowserTool::Tools::GetTextTool, :<, HeadlessBrowserTool::Tools::BaseTool
  end

  def test_tool_has_execute_method
    assert HeadlessBrowserTool::Tools::GetTextTool.method_defined?(:execute)
  end

  def test_tool_registration
    all_tool_names = HeadlessBrowserTool::Tools::ALL_TOOLS.map(&:tool_name)

    assert_includes all_tool_names, "get_text"
  end

  def test_selector_is_required
    # Check that selector is marked as required in the schema
    schema = HeadlessBrowserTool::Tools::GetTextTool.input_schema_to_json

    assert_includes schema[:required], "selector"
  end

  def test_delegates_to_get_page_as_markdown
    # Create the GetTextTool
    get_text_tool = HeadlessBrowserTool::Tools::GetTextTool.new

    # Create a mock GetPageAsMarkdownTool
    mock_markdown_tool = Minitest::Mock.new
    expected_result = { status: "success", result: "Test content" }
    mock_markdown_tool.expect(:execute, expected_result, selector: "#test-selector")

    # Stub the GetPageAsMarkdownTool instantiation
    HeadlessBrowserTool::Tools::GetPageAsMarkdownTool.stub :new, mock_markdown_tool do
      result = get_text_tool.execute(selector: "#test-selector")

      assert_equal expected_result, result
    end

    # Verify the mock was called correctly
    mock_markdown_tool.verify
  end
end
