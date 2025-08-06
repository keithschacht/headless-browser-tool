# frozen_string_literal: true

require "test_helper"

class TestSearchPageTool < Minitest::Test
  def test_tool_exists
    assert defined?(HeadlessBrowserTool::Tools::SearchPageTool)
  end

  def test_tool_inherits_from_base
    assert_operator HeadlessBrowserTool::Tools::SearchPageTool, :<, HeadlessBrowserTool::Tools::BaseTool
  end

  def test_tool_has_execute_method
    assert HeadlessBrowserTool::Tools::SearchPageTool.method_defined?(:execute)
  end

  def test_tool_registration
    all_tool_names = HeadlessBrowserTool::Tools::ALL_TOOLS.map(&:tool_name)
    assert_includes all_tool_names, "search_page"
  end
end