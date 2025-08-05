# frozen_string_literal: true

require "test_helper"

class TestSimpleToolsStructure < Minitest::Test
  def test_tools_exist
    # Test that all the simple tools we want to test exist
    assert defined?(HeadlessBrowserTool::Tools::GetCurrentUrlTool)
    assert defined?(HeadlessBrowserTool::Tools::GetCurrentPathTool)
    assert defined?(HeadlessBrowserTool::Tools::GetPageTitleTool)
    assert defined?(HeadlessBrowserTool::Tools::GetPageSourceTool)
    assert defined?(HeadlessBrowserTool::Tools::HasElementTool)
    assert defined?(HeadlessBrowserTool::Tools::HasTextTool)
    assert defined?(HeadlessBrowserTool::Tools::IsVisibleTool)
    assert defined?(HeadlessBrowserTool::Tools::GetElementContentTool)
  end

  def test_tools_inherit_from_base_tool
    assert_operator HeadlessBrowserTool::Tools::GetCurrentUrlTool, :<, HeadlessBrowserTool::Tools::BaseTool
    assert_operator HeadlessBrowserTool::Tools::GetCurrentPathTool, :<, HeadlessBrowserTool::Tools::BaseTool
    assert_operator HeadlessBrowserTool::Tools::GetPageTitleTool, :<, HeadlessBrowserTool::Tools::BaseTool
  end

  def test_tools_have_execute_method
    tools = [
      HeadlessBrowserTool::Tools::GetCurrentUrlTool,
      HeadlessBrowserTool::Tools::GetCurrentPathTool,
      HeadlessBrowserTool::Tools::GetPageTitleTool,
      HeadlessBrowserTool::Tools::GetPageSourceTool,
      HeadlessBrowserTool::Tools::HasElementTool,
      HeadlessBrowserTool::Tools::HasTextTool,
      HeadlessBrowserTool::Tools::IsVisibleTool
    ]

    tools.each do |tool_class|
      assert tool_class.method_defined?(:execute), "#{tool_class} should have execute method"
    end
  end

  def test_tool_registration
    # Test that tools are properly registered in ALL_TOOLS
    expected_tools = %w[
      get_current_url
      get_current_path
      get_page_title
      get_page_source
      has_element
      has_text
      is_visible
    ]

    all_tool_names = HeadlessBrowserTool::Tools::ALL_TOOLS.map(&:tool_name)

    expected_tools.each do |tool_name|
      assert_includes all_tool_names, tool_name, "#{tool_name} should be in ALL_TOOLS"
    end
  end
end
