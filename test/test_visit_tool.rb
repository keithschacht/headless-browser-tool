# frozen_string_literal: true

require "test_helper"

class TestVisitTool < Minitest::Test
  def test_tool_exists
    assert defined?(HeadlessBrowserTool::Tools::VisitTool)
  end

  def test_tool_inherits_from_base
    assert_operator HeadlessBrowserTool::Tools::VisitTool, :<, HeadlessBrowserTool::Tools::BaseTool
  end

  def test_tool_has_execute_method
    assert HeadlessBrowserTool::Tools::VisitTool.method_defined?(:execute)
  end

  def test_tool_registration
    all_tool_names = HeadlessBrowserTool::Tools::ALL_TOOLS.map(&:tool_name)

    assert_includes all_tool_names, "visit"
  end

  def test_visit_tool_has_required_parameter
    # Test that VisitTool defines url as a required parameter
    tool = HeadlessBrowserTool::Tools::VisitTool.new

    # This should raise an error because url is required
    assert_raises(ArgumentError) do
      tool.execute
    end
  end
end
