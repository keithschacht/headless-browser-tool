# frozen_string_literal: true

require "test_helper"

class TestOpenNewWindowTool < Minitest::Test
  def test_tool_exists
    assert defined?(HeadlessBrowserTool::Tools::OpenNewWindowTool)
  end

  def test_tool_inherits_from_base
    assert_operator HeadlessBrowserTool::Tools::OpenNewWindowTool, :<, HeadlessBrowserTool::Tools::BaseTool
  end

  def test_tool_has_execute_method
    assert HeadlessBrowserTool::Tools::OpenNewWindowTool.method_defined?(:execute)
  end

  def test_tool_registration
    all_tool_names = HeadlessBrowserTool::Tools::ALL_TOOLS.map(&:tool_name)

    assert_includes all_tool_names, "open_new_window"
  end
end
