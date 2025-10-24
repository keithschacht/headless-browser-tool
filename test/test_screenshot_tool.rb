# frozen_string_literal: true

require_relative "test_base"

class TestScreenshotTool < TestBase
  def setup
    super
    @browser = HeadlessBrowserTool::Browser.new(headless: true, be_human: true)

    HeadlessBrowserTool::Server.instance_variable_set(:@single_session_mode, true)
    HeadlessBrowserTool::Server.instance_variable_set(:@browser_instance, @browser)

    @tool = HeadlessBrowserTool::Tools::ScreenshotTool.new

    html = "<html><body><h1>Test Page</h1></body></html>"
    @browser.visit "data:text/html,#{html.gsub(/\s+/, " ").strip}"
  end

  def teardown
    begin
      @browser = nil
    rescue StandardError
      nil
    end
    super
  end

  def test_tool_exists
    assert defined?(HeadlessBrowserTool::Tools::ScreenshotTool)
  end

  def test_tool_inherits_from_base
    assert_operator HeadlessBrowserTool::Tools::ScreenshotTool, :<, HeadlessBrowserTool::Tools::BaseTool
  end

  def test_tool_has_execute_method
    assert HeadlessBrowserTool::Tools::ScreenshotTool.method_defined?(:execute)
  end

  def test_tool_registration
    all_tool_names = HeadlessBrowserTool::Tools::ALL_TOOLS.map(&:tool_name)

    assert_includes all_tool_names, "screenshot"
  end

  def test_screenshot_path_with_relative_hbt_dir
    original_hbt_dir = ENV["HBT_DIR"]
    original_screenshots_dir = ENV["HBT_SCREENSHOTS_DIR"]

    begin
      ENV["HBT_DIR"] = "./sandbox/.hbt"
      ENV["HBT_SCREENSHOTS_DIR"] = nil

      load File.expand_path("../lib/headless_browser_tool/directory_setup.rb", __dir__)
      HeadlessBrowserTool::DirectorySetup.setup_directories

      result = @tool.execute

      assert_kind_of Hash, result
      assert result[:file_path].start_with?(".hbt/screenshots/"),
             "Expected file_path to start with '.hbt/screenshots/' but got: #{result[:file_path]}"

      full_path = File.join("./sandbox", result[:file_path])
      assert File.exist?(full_path), "Screenshot file should exist at: #{full_path}"
    ensure
      ENV["HBT_DIR"] = original_hbt_dir
      ENV["HBT_SCREENSHOTS_DIR"] = original_screenshots_dir
      load File.expand_path("../lib/headless_browser_tool/directory_setup.rb", __dir__)
    end
  end

  def test_screenshot_path_with_absolute_hbt_dir_and_trailing_slash
    original_hbt_dir = ENV["HBT_DIR"]
    original_screenshots_dir = ENV["HBT_SCREENSHOTS_DIR"]

    begin
      test_dir = File.join(Dir.tmpdir, "hbt_test_#{Process.pid}_#{Time.now.to_i}")
      hbt_dir = File.join(test_dir, "sandbox", ".hbt")
      FileUtils.mkdir_p(File.join(hbt_dir, "screenshots"))

      ENV["HBT_DIR"] = "#{hbt_dir}/"
      ENV["HBT_SCREENSHOTS_DIR"] = nil

      load File.expand_path("../lib/headless_browser_tool/directory_setup.rb", __dir__)
      HeadlessBrowserTool::DirectorySetup.setup_directories

      result = @tool.execute

      assert_kind_of Hash, result
      assert result[:file_path].start_with?(".hbt/screenshots/"),
             "Expected file_path to start with '.hbt/screenshots/' but got: #{result[:file_path]}"

      full_path = File.join(hbt_dir, "screenshots", File.basename(result[:file_path]))
      assert File.exist?(full_path), "Screenshot file should exist at: #{full_path}"
    ensure
      FileUtils.rm_rf(test_dir) if test_dir && File.exist?(test_dir)
      ENV["HBT_DIR"] = original_hbt_dir
      ENV["HBT_SCREENSHOTS_DIR"] = original_screenshots_dir
      load File.expand_path("../lib/headless_browser_tool/directory_setup.rb", __dir__)
    end
  end
end
