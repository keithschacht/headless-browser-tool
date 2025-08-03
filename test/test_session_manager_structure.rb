# frozen_string_literal: true

require "test_helper"

class TestSessionManagerStructure < Minitest::Test
  def test_session_manager_exists
    assert defined?(HeadlessBrowserTool::SessionManager)
  end

  def test_session_manager_methods
    manager_class = HeadlessBrowserTool::SessionManager

    # Public methods
    assert manager_class.method_defined?(:get_or_create_session)
    assert manager_class.method_defined?(:close_session)
    assert manager_class.method_defined?(:session_info)
    assert manager_class.method_defined?(:save_all_sessions)

    # Private methods
    assert manager_class.private_method_defined?(:cleanup_idle_sessions)
    assert manager_class.private_method_defined?(:cleanup_least_recently_used)
    assert manager_class.private_method_defined?(:start_cleanup_thread)
  end

  def test_session_constants
    assert_equal 1800, HeadlessBrowserTool::SessionManager::SESSION_TIMEOUT # 30 minutes
    assert_equal 60, HeadlessBrowserTool::SessionManager::CLEANUP_INTERVAL
    assert_equal 10, HeadlessBrowserTool::SessionManager::MAX_SESSIONS
  end

  def test_browser_adapter_structure
    adapter_class = HeadlessBrowserTool::BrowserAdapter

    # Test it has the expected instance variables
    adapter = adapter_class.allocate # Create without calling initialize

    assert_respond_to adapter, :session
    assert_respond_to adapter, :session_id
    assert_respond_to adapter, :previous_state
    assert_respond_to adapter, :previous_state=
  end
end
