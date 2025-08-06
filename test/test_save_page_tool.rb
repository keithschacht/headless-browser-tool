# frozen_string_literal: true

require "test_helper"

class TestSavePageTool < Minitest::Test
  def test_tool_exists
    assert defined?(HeadlessBrowserTool::Tools::SavePageTool)
  end

  def test_tool_inherits_from_base
    assert_operator HeadlessBrowserTool::Tools::SavePageTool, :<, HeadlessBrowserTool::Tools::BaseTool
  end

  def test_tool_has_execute_method
    assert HeadlessBrowserTool::Tools::SavePageTool.method_defined?(:execute)
  end

  def test_tool_registration
    all_tool_names = HeadlessBrowserTool::Tools::ALL_TOOLS.map(&:tool_name)
    assert_includes all_tool_names, "save_page"
  end
end