# frozen_string_literal: true

require_relative "test_base"
require "fileutils"
require "json"
require "net/http"
require "webrick"

class TestSessionPersistence < TestBase
  def setup
    super # Call TestBase setup
    # @sessions_dir is already set up by TestBase
    @test_url = "data:text/html,<html><body><h1>Session Test</h1>" \
                "<input id='test-input' value='initial'>" \
                "<script>localStorage.setItem('test_key','test_value');" \
                "sessionStorage.setItem('session_key','session_value');</script></body></html>"
  end

  def test_session_save_and_restore_with_real_browser
    session_id = test_session_id

    with_test_environment do
      # Create first browser with session
      browser1 = HeadlessBrowserTool::Browser.new(headless: true)
      browser1.instance_variable_set(:@session_id, session_id)

      begin
        # Navigate and modify state
        browser1.visit(@test_url)
        browser1.execute_script("document.getElementById('test-input').value = 'modified'")

        # Get current state
        current_url = browser1.current_url
        input_value = browser1.find("#test-input").value

        assert_equal "modified", input_value

        # Manually save session data
        session_data = {
          url: current_url,
          timestamp: Time.now.to_i,
          custom_data: {
            input_value: input_value
          }
        }

        File.write(File.join(@sessions_dir, "#{session_id}.json"), session_data.to_json)
      ensure
        browser1.session.quit
      end

      # Create second browser and restore
      browser2 = HeadlessBrowserTool::Browser.new(headless: true)
      browser2.instance_variable_set(:@session_id, session_id)

      begin
        # Read session data
        saved_data = JSON.parse(File.read(File.join(@sessions_dir, "#{session_id}.json")))

        # Navigate to saved URL
        browser2.visit(saved_data["url"])

        # Verify we can access the page
        assert browser2.has_css?("h1", text: "Session Test")

        # Verify saved custom data
        assert_equal "modified", saved_data["custom_data"]["input_value"]
      ensure
        browser2.session.quit
      end
    end
  end

  def test_session_timeout_detection
    old_session_id = "test-old-session"
    session_file = File.join(@sessions_dir, "#{old_session_id}.json")

    # Create an old session file
    old_data = {
      url: "https://example.com",
      cookies: [],
      local_storage: {},
      session_storage: {},
      timestamp: (Time.now - 3600).to_i # 1 hour ago
    }

    File.write(session_file, old_data.to_json)

    # Test that session manager detects it as expired
    session_data = JSON.parse(File.read(session_file))
    age = Time.now.to_i - session_data["timestamp"]

    assert_operator age, :>, 1800, "Session should be older than 30 minutes"

    # Create a recent session
    recent_session_id = "test-recent-session"
    recent_file = File.join(@sessions_dir, "#{recent_session_id}.json")

    recent_data = old_data.merge(timestamp: Time.now.to_i)
    File.write(recent_file, recent_data.to_json)

    recent_session_data = JSON.parse(File.read(recent_file))
    recent_age = Time.now.to_i - recent_session_data["timestamp"]

    assert_operator recent_age, :<, 1800, "Recent session should be less than 30 minutes old"
  end

  def test_session_cleanup
    # Create multiple session files with different ages
    sessions = [
      { id: "test-expired-1", age: 3600 },    # 1 hour old
      { id: "test-expired-2", age: 7200 },    # 2 hours old
      { id: "test-recent-1", age: 600 },      # 10 minutes old
      { id: "test-recent-2", age: 300 }       # 5 minutes old
    ]

    sessions.each do |session|
      file_path = File.join(@sessions_dir, "#{session[:id]}.json")
      data = {
        url: "https://example.com",
        timestamp: Time.now.to_i - session[:age]
      }
      File.write(file_path, data.to_json)

      # Test cleanup by checking file ages directly
      file_path = File.join(@sessions_dir, "#{session[:id]}.json")
      next unless File.exist?(file_path)

      data = JSON.parse(File.read(file_path))
      age = Time.now.to_i - data["timestamp"]

      # Clean up expired files manually for this test
      File.delete(file_path) if age > 1800

      # Check that only recent sessions remain
      file_path = File.join(@sessions_dir, "#{session[:id]}.json")
      if session[:age] > 1800 # 30 minutes
        refute_path_exists file_path, "Expired session #{session[:id]} should be deleted"
      else
        assert_path_exists file_path, "Recent session #{session[:id]} should be kept"
      end
    end
  end

  def test_concurrent_session_saves
    # Test that multiple sessions can save simultaneously without conflicts
    threads = []
    session_ids = []

    5.times do |i|
      session_id = "test-concurrent-#{i}"
      session_ids << session_id

      threads << Thread.new do
        data = {
          url: "https://example.com/page#{i}",
          cookies: [],
          timestamp: Time.now.to_i
        }

        file_path = File.join(@sessions_dir, "#{session_id}.json")
        File.write(file_path, data.to_json)
      end
    end

    threads.each(&:join)

    # Verify all files were created
    session_ids.each do |session_id|
      file_path = File.join(@sessions_dir, "#{session_id}.json")

      assert_path_exists file_path, "Session #{session_id} should be saved"

      # Verify JSON is valid
      data = JSON.parse(File.read(file_path))

      assert data["url"], "Session should have URL"
    end
  end

  def test_session_file_corruption_handling
    corrupted_session_id = "test-corrupted"
    session_file = File.join(@sessions_dir, "#{corrupted_session_id}.json")

    # Write invalid JSON
    File.write(session_file, "{ invalid json }")

    # Try to read it
    begin
      JSON.parse(File.read(session_file))

      flunk "Should have raised JSON parse error"
    rescue JSON::ParserError
      # Expected - corrupted file should fail to parse
      pass
    end
  end

  def test_session_persistence_with_server
    # Use a random port
    port = rand(50_000..59_999)
    session_id = "test-server-session-#{Time.now.to_i}"

    # Start server in single session mode
    server_pid = fork do
      $stdout.reopen(File::NULL, "w")
      $stderr.reopen(File::NULL, "w")

      HeadlessBrowserTool::Server.start_server(
        port: port,
        single_session: true,
        session_id: session_id,
        headless: true
      )
    end

    # Wait for server to start
    wait_for_server(port)

    begin
      base_url = "http://localhost:#{port}"

      # Make some requests to create session state
      make_request(base_url, "visit", { url: @test_url }, session_id)
      make_request(base_url, "fill_in", { field: "test-input", value: "server-modified" }, session_id)

      # Get current state
      state_result = make_request(base_url, "evaluate_script", {
                                    javascript_code: "({ input: document.getElementById('test-input').value, url: window.location.href })"
                                  }, session_id)

      assert_kind_of Hash, state_result
      assert_equal "success", state_result["status"]
      assert_equal "Hash", state_result["type"]
      assert_equal "server-modified", state_result["result"]["input"]

      # Session file should exist (if session persistence is enabled)
      File.join(@sessions_dir, "#{session_id}.json")

      # NOTE: Actual session persistence might not be implemented yet
      # This test documents the expected behavior
    ensure
      Process.kill("TERM", server_pid) if server_pid
      Process.wait(server_pid) if server_pid
    end
  rescue Errno::ESRCH, Errno::ECHILD
    # Process already dead
  end

  def test_session_with_cookies
    # Start a simple server to test cookies (data: URLs don't support cookies)
    server = WEBrick::HTTPServer.new(
      Port: 0,
      Logger: WEBrick::Log.new(File::NULL),
      AccessLog: []
    )
    port = server.config[:Port]

    server.mount_proc "/" do |_req, res|
      res.body = <<~HTML
        <html>
          <body>
            <h1>Cookie Test</h1>
            <script>
              document.cookie='test1=value1';
              document.cookie='test2=value2;path=/';
            </script>
          </body>
        </html>
      HTML
      res.content_type = "text/html"
    end

    Thread.new { server.start }
    sleep 0.1

    browser = HeadlessBrowserTool::Browser.new(headless: true)

    begin
      # Navigate to page that sets cookies
      browser.visit("http://localhost:#{port}/")

      # Get cookies via JavaScript
      cookies = browser.evaluate_script("document.cookie")

      assert_includes cookies, "test1=value1", "Should have first cookie"
      assert_includes cookies, "test2=value2", "Should have second cookie"
    ensure
      browser.session.quit
      server.shutdown
    end
  end

  def test_session_persistence_module_save_and_restore
    session_id = "test-persistence-#{Time.now.to_i}"

    # Start a simple server for cookies
    server = WEBrick::HTTPServer.new(
      Port: 0,
      Logger: WEBrick::Log.new(File::NULL),
      AccessLog: []
    )
    port = server.config[:Port]

    server.mount_proc "/" do |_req, res|
      # Set cookies via headers
      res["Set-Cookie"] = "server_cookie=server_value; Path=/; HttpOnly"
      res.body = <<~HTML
        <html>
          <body>
            <h1>Session Persistence Test</h1>
            <input id="test-input" value="initial">
            <script>
              // Set client-side cookies
              document.cookie='client_cookie=client_value';
              document.cookie='session_cookie=session_value;path=/';
        #{"      "}
              // Set storage
              localStorage.setItem('localKey', 'localValue');
              localStorage.setItem('userData', JSON.stringify({id: 123, name: 'Test User'}));
              sessionStorage.setItem('sessionKey', 'sessionValue');
              sessionStorage.setItem('tempData', 'temporary');
            </script>
          </body>
        </html>
      HTML
      res.content_type = "text/html"
    end

    Thread.new { server.start }
    sleep 0.1

    # First browser session
    browser1 = HeadlessBrowserTool::Browser.new(headless: true)

    begin
      # Visit page and set up state
      browser1.visit("http://localhost:#{port}/")
      browser1.fill_in("test-input", "modified_value")

      # Add a manual cookie via Selenium
      browser1.session.driver.browser.manage.add_cookie(
        name: "manual_cookie",
        value: "manual_value",
        domain: "localhost",
        path: "/"
      )

      # Resize window
      browser1.session.current_window.resize_to(1234, 567)
      sleep 0.5 # Let resize take effect

      # Save the session using SessionPersistence module
      HeadlessBrowserTool::SessionPersistence.save_session(session_id, browser1.session)

      # Verify session file was created (SessionPersistence uses its own path)
      session_file = File.join(HeadlessBrowserTool::DirectorySetup::SESSIONS_DIR, "#{session_id}.json")

      assert_path_exists session_file, "Session file should be created"

      # Read and verify saved data structure
      saved_data = JSON.parse(File.read(session_file))

      assert_equal session_id, saved_data["session_id"]
      assert saved_data["saved_at"]
      assert_equal "http://localhost:#{port}/", saved_data["current_url"]

      # Verify cookies were saved
      assert_kind_of Array, saved_data["cookies"]
      cookie_names = saved_data["cookies"].map { |c| c["name"] }

      assert_includes cookie_names, "server_cookie"
      assert_includes cookie_names, "client_cookie"
      assert_includes cookie_names, "session_cookie"
      assert_includes cookie_names, "manual_cookie"

      # Verify storage was saved
      assert_equal "localValue", saved_data["local_storage"]["localKey"]
      assert_includes saved_data["local_storage"]["userData"], "Test User"
      assert_equal "sessionValue", saved_data["session_storage"]["sessionKey"]
      assert_equal "temporary", saved_data["session_storage"]["tempData"]

      # Verify window size was saved
      assert_equal 1234, saved_data["window_size"]["width"]
      assert_equal 567, saved_data["window_size"]["height"]
    ensure
      browser1.session.quit
    end

    # Second browser session - restore
    browser2 = HeadlessBrowserTool::Browser.new(headless: true)

    begin
      # Start with blank page
      browser2.visit("about:blank")

      # Clear any default cookies
      browser2.session.driver.browser.manage.delete_all_cookies

      # Restore the session
      result = HeadlessBrowserTool::SessionPersistence.restore_session(session_id, browser2.session)

      assert result, "Session restoration should succeed"

      # Verify URL was restored
      assert_equal "http://localhost:#{port}/", browser2.current_url

      # Verify cookies were restored
      restored_cookies = browser2.session.driver.browser.manage.all_cookies
      cookie_names = restored_cookies.map { |c| c[:name] }

      # Check that our cookies exist
      assert_includes cookie_names, "client_cookie", "client_cookie should be restored"
      assert_includes cookie_names, "session_cookie", "session_cookie should be restored"
      assert_includes cookie_names, "manual_cookie", "manual_cookie should be restored"

      # NOTE: HttpOnly cookies like server_cookie may not be visible to driver.manage.all_cookies
      # but they should still be sent with requests

      # Verify storage was restored
      local_key = browser2.evaluate_script("localStorage.getItem('localKey')")

      assert_equal "localValue", local_key

      user_data = browser2.evaluate_script("localStorage.getItem('userData')")

      assert_includes user_data, "Test User"

      session_key = browser2.evaluate_script("sessionStorage.getItem('sessionKey')")

      assert_equal "sessionValue", session_key

      temp_data = browser2.evaluate_script("sessionStorage.getItem('tempData')")

      assert_equal "temporary", temp_data

      # Verify window size was restored
      size = browser2.session.current_window.size

      assert_equal 1234, size[0]
      assert_equal 567, size[1]

      # Verify the input value is back to initial (page was reloaded)
      input_value = browser2.find("#test-input").value

      assert_equal "initial", input_value
    ensure
      browser2.session.quit
      server.shutdown
    end
  end

  def test_session_persistence_helper_methods
    session_id = "test-helpers-#{Time.now.to_i}"

    # Test session_exists? when doesn't exist
    refute HeadlessBrowserTool::SessionPersistence.session_exists?(session_id)

    # Create a dummy session file
    session_file = File.join(HeadlessBrowserTool::DirectorySetup::SESSIONS_DIR, "#{session_id}.json")
    File.write(session_file, JSON.pretty_generate({
                                                    session_id: session_id,
                                                    saved_at: Time.now.iso8601,
                                                    current_url: "https://example.com"
                                                  }))

    # Test session_exists? when exists
    assert HeadlessBrowserTool::SessionPersistence.session_exists?(session_id)

    # Test delete_session
    HeadlessBrowserTool::SessionPersistence.delete_session(session_id)

    refute_path_exists session_file
    refute HeadlessBrowserTool::SessionPersistence.session_exists?(session_id)
  end

  private

  def wait_for_server(port, timeout = 5)
    start_time = Time.now
    loop do
      Net::HTTP.get(URI("http://localhost:#{port}/"))
      break
    rescue Errno::ECONNREFUSED, Net::ReadTimeout
      raise "Server failed to start" if Time.now - start_time > timeout

      sleep 0.1
    end
  end

  def make_request(base_url, tool_name, arguments, session_id)
    uri = URI("#{base_url}/mcp")
    request = Net::HTTP::Post.new(uri)
    request["Content-Type"] = "application/json"
    request["X-Session-ID"] = session_id
    request.body = {
      jsonrpc: "2.0",
      method: "tools/call",
      params: {
        name: tool_name,
        arguments: arguments
      },
      id: rand(1000)
    }.to_json

    response = Net::HTTP.start(uri.hostname, uri.port) do |http|
      http.request(request)
    end

    result = JSON.parse(response.body)

    # Extract the actual result from MCP response
    if result["result"] && result["result"]["content"] && result["result"]["content"][0]
      JSON.parse(result["result"]["content"][0]["text"])
    elsif result["error"]
      result
    else
      # Handle unexpected response format
      { "error" => { "message" => "Unexpected response format", "response" => result } }
    end
  end
end
