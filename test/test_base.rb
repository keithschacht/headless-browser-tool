# frozen_string_literal: true

require "test_helper"
require "fileutils"
require "tmpdir"

# Base class for tests that need isolated environments
class TestBase < Minitest::Test
  attr_reader :test_dir, :test_id, :port

  def setup
    super
    # Generate unique test ID based on process, thread, and counter
    @test_id = generate_test_id

    # Create isolated test directory
    @test_dir = File.join(Dir.tmpdir, "hbt_test_#{@test_id}")
    FileUtils.mkdir_p(@test_dir)

    puts "Created test directory: #{@test_dir}" if ENV["DEBUG_TESTS"]

    # Set up isolated .hbt directory structure
    @hbt_dir = File.join(@test_dir, ".hbt")
    @sessions_dir = File.join(@hbt_dir, "sessions")
    @screenshots_dir = File.join(@hbt_dir, "screenshots")
    @logs_dir = File.join(@hbt_dir, "logs")

    FileUtils.mkdir_p(@sessions_dir)
    FileUtils.mkdir_p(@screenshots_dir)
    FileUtils.mkdir_p(@logs_dir)

    # Track created processes for cleanup
    @child_pids = []
  end

  def teardown
    # Kill any child processes
    @child_pids.each do |pid|
      Process.kill("TERM", pid)
      # Give it a moment to terminate gracefully
      sleep 0.1
      Process.kill("KILL", pid)
    rescue Errno::ESRCH
      # Process already dead

      # Wait for all child processes to exit

      Process.wait(pid)
    rescue Errno::ECHILD
      # Already reaped
    end

    # Clean up Chrome processes that might be lingering
    # Look for Chrome processes with our test directory in the command line
    `pkill -f "chrome.*#{@test_dir}" 2>/dev/null` if @test_dir

    # Clean up test directory
    FileUtils.rm_rf(@test_dir) if @test_dir && File.exist?(@test_dir)

    # Release port if allocated
    TestServerHelper.release_port(@port) if @port

    super
  rescue StandardError => e
    # Don't let cleanup errors fail the test
    puts "Cleanup error: #{e.message}" if ENV["DEBUG_TESTS"]
  end

  protected

  def generate_test_id
    # Use the same approach as port allocation
    @test_counter ||= 0
    @test_counter = TestServerHelper.instance_variable_get(:@test_counter) || 0
    "#{Process.pid}_#{Thread.current.object_id.to_s(16)}_#{@test_counter}"
  end

  def allocate_test_port
    @port = TestServerHelper.allocate_port
  end

  def track_child_process(pid)
    @child_pids << pid if pid
  end

  def test_session_id
    "test_#{@test_id}"
  end

  def test_screenshot_name(base_name = "screenshot")
    "test_#{@test_id}_#{base_name}"
  end

  def with_test_environment
    # Temporarily override HBT directories to use our isolated ones
    old_sessions = ENV.fetch("HBT_SESSIONS_DIR", nil)
    old_screenshots = ENV.fetch("HBT_SCREENSHOTS_DIR", nil)
    old_logs = ENV.fetch("HBT_LOGS_DIR", nil)

    ENV["HBT_SESSIONS_DIR"] = @sessions_dir
    ENV["HBT_SCREENSHOTS_DIR"] = @screenshots_dir
    ENV["HBT_LOGS_DIR"] = @logs_dir

    yield
  ensure
    ENV["HBT_SESSIONS_DIR"] = old_sessions
    ENV["HBT_SCREENSHOTS_DIR"] = old_screenshots
    ENV["HBT_LOGS_DIR"] = old_logs
  end
end
