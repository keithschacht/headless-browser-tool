# frozen_string_literal: true

require "test_helper"
require "tempfile"

class TestLogger < Minitest::Test
  def setup
    # Reset logger state before each test
    HeadlessBrowserTool::Logger.instance_variable_set(:@log, nil)
  end

  def test_logger_uses_log_instance_variable
    # Initialize logger
    HeadlessBrowserTool::Logger.initialize_logger(mode: :http)

    # Verify @log is set
    assert_instance_of Logger, HeadlessBrowserTool::Logger.instance_variable_get(:@log)

    # Verify log method returns the logger
    assert_instance_of Logger, HeadlessBrowserTool::Logger.log

    # Verify both .log and .instance return the same object
    assert_equal HeadlessBrowserTool::Logger.log, HeadlessBrowserTool::Logger.instance
  end

  def test_http_mode_logs_to_stdout
    # Capture stdout
    original_stdout = $stdout
    captured_output = StringIO.new
    $stdout = captured_output

    begin
      HeadlessBrowserTool::Logger.initialize_logger(mode: :http)
      HeadlessBrowserTool::Logger.log.info "Test message via log"
      HeadlessBrowserTool::Logger.instance.info "Test message via instance"

      output = captured_output.string

      assert_match(/Test message via log/, output)
      assert_match(/Test message via instance/, output)
    ensure
      $stdout = original_stdout
    end
  end

  def test_stdio_mode_logs_to_file
    # Initialize in stdio mode
    HeadlessBrowserTool::Logger.initialize_logger(mode: :stdio)

    # The logger should not be outputting to stdout in stdio mode
    captured_output = StringIO.new
    original_stdout = $stdout
    $stdout = captured_output

    begin
      HeadlessBrowserTool::Logger.log.info "Test message via log"
      HeadlessBrowserTool::Logger.instance.info "Test message via instance"

      # In stdio mode, nothing should go to stdout
      assert_empty captured_output.string

      # Verify a log file was created in the .hbt/logs directory
      log_files = Dir.glob(File.join(HeadlessBrowserTool::DirectorySetup::LOGS_DIR, "*.log"))

      assert_predicate log_files, :any?, "At least one log file should exist"
    ensure
      $stdout = original_stdout
    end
  end

  def test_rubocop_compatibility
    # This test ensures that the logger works with @log instead of @instance
    # which is what rubocop -A would change it to

    # Simulate what rubocop would do - use @log directly
    logger_instance = Logger.new(StringIO.new)
    HeadlessBrowserTool::Logger.instance_variable_set(:@log, logger_instance)

    # Verify it still works
    assert_equal logger_instance, HeadlessBrowserTool::Logger.log
    assert_equal logger_instance, HeadlessBrowserTool::Logger.instance
  end

  def test_backward_compatibility_with_instance_method
    HeadlessBrowserTool::Logger.initialize_logger(mode: :http)

    # The .instance method should still work for backward compatibility
    assert_respond_to HeadlessBrowserTool::Logger, :instance
    assert_instance_of Logger, HeadlessBrowserTool::Logger.instance
  end
end
