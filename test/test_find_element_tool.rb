# frozen_string_literal: true

require "test_helper"

class TestFindElementTool < Minitest::Test
  def test_tool_exists
    assert defined?(HeadlessBrowserTool::Tools::FindElementTool)
  end

  def test_tool_inherits_from_base
    assert_operator HeadlessBrowserTool::Tools::FindElementTool, :<, HeadlessBrowserTool::Tools::BaseTool
  end

  def test_tool_has_execute_method
    assert HeadlessBrowserTool::Tools::FindElementTool.method_defined?(:execute)
  end

  def test_tool_registration
    all_tool_names = HeadlessBrowserTool::Tools::ALL_TOOLS.map(&:tool_name)
    assert_includes all_tool_names, "find_element"
  end
end