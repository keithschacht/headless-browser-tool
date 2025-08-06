# frozen_string_literal: true

require "test_helper"

class TestSwitchToWindowTool < Minitest::Test
  def test_tool_exists
    assert defined?(HeadlessBrowserTool::Tools::SwitchToWindowTool)
  end

  def test_tool_inherits_from_base
    assert_operator HeadlessBrowserTool::Tools::SwitchToWindowTool, :<, HeadlessBrowserTool::Tools::BaseTool
  end

  def test_tool_has_execute_method
    assert HeadlessBrowserTool::Tools::SwitchToWindowTool.method_defined?(:execute)
  end

  def test_tool_registration
    all_tool_names = HeadlessBrowserTool::Tools::ALL_TOOLS.map(&:tool_name)

    assert_includes all_tool_names, "switch_to_window"
  end
end
