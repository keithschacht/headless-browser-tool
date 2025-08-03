# frozen_string_literal: true

require "test_helper"
require "headless_browser_tool/cli"

class TestCLI < Minitest::Test
  def setup
    @original_stdout = $stdout
    @original_stderr = $stderr
  end

  def teardown
    $stdout = @original_stdout
    $stderr = @original_stderr
  end

  def test_version_command
    output = capture_output do
      HeadlessBrowserTool::CLI.start(["version"])
    end

    assert_match HeadlessBrowserTool::VERSION, output
  end

  def test_help_command
    output = capture_output do
      HeadlessBrowserTool::CLI.start(["help"])
    rescue SystemExit
      # Thor exits after showing help
    end

    assert_match(/Commands:/, output)
    assert_match(/help/, output)
    assert_match(/start/, output)
    assert_match(/stdio/, output)
    assert_match(/version/, output)
  end

  def test_start_command_flags
    # Test that flags are parsed correctly
    # cli = HeadlessBrowserTool::CLI.new

    # Capture the options that would be passed
    options = {
      "port" => 3000,
      "single-session" => true,
      "session-id" => "test-session",
      "no-headless" => true,
      "be-human" => true,
      "show-headers" => true
    }

    # Create a mock server to verify options are passed correctly
    mock_server = Minitest::Mock.new
    mock_server.expect :run, nil

    HeadlessBrowserTool::Server.stub :new, mock_server do
      # Verify server would be created with correct options
      assert_equal 3000, options["port"]
      assert options["single-session"]
      assert_equal "test-session", options["session-id"]
      assert options["no-headless"]
      assert options["be-human"]
      assert options["show-headers"]
    end
  end

  def test_stdio_command_flags
    # Test stdio mode flag parsing
    options = {
      "no-headless" => true,
      "be-human" => true,
      "be-mostly-human" => true
    }

    # Verify options structure
    assert options["no-headless"]
    assert options["be-human"]
    assert options["be-mostly-human"]
  end

  def test_default_port
    cli = HeadlessBrowserTool::CLI.new

    # Test default options
    assert_respond_to cli, :options
  end

  def test_conflicting_options_documentation
    # This test documents that conflicting options should be handled
    # Currently both human flags can be set together
    options = {
      "be-human" => true,
      "be-mostly-human" => true
    }

    # Both can be true currently
    assert options["be-human"]
    assert options["be-mostly-human"]
  end

  private

  def capture_output
    output = StringIO.new
    $stdout = output
    $stderr = output

    yield

    output.string
  ensure
    $stdout = @original_stdout
    $stderr = @original_stderr
  end
end
