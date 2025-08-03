# frozen_string_literal: true

require "test_helper"

class TestNavigationToolsStructure < Minitest::Test
  def test_navigation_tools_exist
    assert defined?(HeadlessBrowserTool::Tools::VisitTool)
    assert defined?(HeadlessBrowserTool::Tools::RefreshTool)
    assert defined?(HeadlessBrowserTool::Tools::GoBackTool)
    assert defined?(HeadlessBrowserTool::Tools::GoForwardTool)
  end

  def test_navigation_tools_inherit_from_base
    assert_operator HeadlessBrowserTool::Tools::VisitTool, :<, HeadlessBrowserTool::Tools::BaseTool
    assert_operator HeadlessBrowserTool::Tools::RefreshTool, :<, HeadlessBrowserTool::Tools::BaseTool
    assert_operator HeadlessBrowserTool::Tools::GoBackTool, :<, HeadlessBrowserTool::Tools::BaseTool
    assert_operator HeadlessBrowserTool::Tools::GoForwardTool, :<, HeadlessBrowserTool::Tools::BaseTool
  end

  def test_visit_tool_has_required_parameter
    # Test that VisitTool defines url as a required parameter
    tool = HeadlessBrowserTool::Tools::VisitTool.new

    # This should raise an error because url is required
    assert_raises(ArgumentError) do
      tool.execute
    end
  end

  def test_navigation_tools_registered
    all_tool_names = HeadlessBrowserTool::Tools::ALL_TOOLS.map(&:tool_name)

    assert_includes all_tool_names, "visit"
    assert_includes all_tool_names, "refresh"
    assert_includes all_tool_names, "go_back"
    assert_includes all_tool_names, "go_forward"
  end
end
