# frozen_string_literal: true

require "json"
require "fileutils"
require "time"
require_relative "logger"
require_relative "directory_setup"

module HeadlessBrowserTool
  module SessionPersistence # rubocop:disable Metrics/ModuleLength
    BLANK_URLS = ["about:blank", "data:,"].freeze

    module_function

    def save_session(session_id, capybara_session)
      HeadlessBrowserTool::Logger.log.info "=== Starting save_session ==="
      HeadlessBrowserTool::Logger.log.info "Session ID: #{session_id.inspect}, Capybara session present: #{!capybara_session.nil?}"

      return unless session_id && capybara_session

      FileUtils.mkdir_p(DirectorySetup::SESSIONS_DIR)
      session_file = File.join(DirectorySetup::SESSIONS_DIR, "#{session_id}.json")
      HeadlessBrowserTool::Logger.log.info "Session file path: #{session_file}"

      begin
        state = {
          session_id: session_id,
          saved_at: Time.now.iso8601,
          current_url: capybara_session.current_url,
          cookies: extract_cookies(capybara_session),
          local_storage: extract_storage(capybara_session, "localStorage"),
          session_storage: extract_storage(capybara_session, "sessionStorage"),
          window_size: extract_window_size(capybara_session)
        }

        # Don't overwrite existing session with blank data
        # Check if there's an existing session file with data
        if BLANK_URLS.include?(state[:current_url]) && state[:cookies].empty? && File.exist?(session_file)
          existing_state = JSON.parse(File.read(session_file))
          # If existing session has cookies or meaningful URL, don't overwrite with blank
          if !existing_state["cookies"].empty? || !BLANK_URLS.include?(existing_state["current_url"])
            HeadlessBrowserTool::Logger.log.info "Skipping save - would overwrite existing session with blank data"
            HeadlessBrowserTool::Logger.log.info "  Current: #{state[:current_url]} with #{state[:cookies].length} cookies"
            HeadlessBrowserTool::Logger.log.info "  Existing: #{existing_state["current_url"]} with #{existing_state["cookies"].length} cookies"
            return
          end
        end

        HeadlessBrowserTool::Logger.log.info "Writing session state to file with #{state[:cookies]&.length || 0} cookies"
        File.write(session_file, JSON.pretty_generate(state))
        HeadlessBrowserTool::Logger.log.info "=== Session saved successfully to #{session_file} ==="
      rescue StandardError => e
        HeadlessBrowserTool::Logger.log.info "ERROR saving session: #{e.message}"
        HeadlessBrowserTool::Logger.log.info "Backtrace: #{e.backtrace.first(3).join("\n  ")}"
      end
    end

    def restore_session(session_id, capybara_session)
      # Add nil checks for session_id and capybara_session
      unless session_id && capybara_session
        HeadlessBrowserTool::Logger.log.info "WARNING: Cannot restore session - session_id or capybara_session is nil"
        return false
      end

      session_file = File.join(DirectorySetup::SESSIONS_DIR, "#{session_id}.json")

      HeadlessBrowserTool::Logger.log.info "=== Starting session restoration for: #{session_id} ==="
      HeadlessBrowserTool::Logger.log.info "Session file path: #{session_file}"
      HeadlessBrowserTool::Logger.log.info "Session file exists: #{File.exist?(session_file)}"

      return unless File.exist?(session_file)

      begin
        state = JSON.parse(File.read(session_file))
        HeadlessBrowserTool::Logger.log.info "Loaded session state from file"
        HeadlessBrowserTool::Logger.log.info "  - Saved at: #{state["saved_at"]}"
        HeadlessBrowserTool::Logger.log.info "  - URL: #{state["current_url"]}"
        HeadlessBrowserTool::Logger.log.info "  - Cookies count: #{state["cookies"]&.length || 0}"
        HeadlessBrowserTool::Logger.log.info "  - LocalStorage items: #{state["local_storage"]&.length || 0}"
        HeadlessBrowserTool::Logger.log.info "  - SessionStorage items: #{state["session_storage"]&.length || 0}"

        # Navigate to the saved URL if present
        if state["current_url"]
          begin
            uri = URI.parse(state["current_url"])
            # Include port if present
            domain_url = if uri.port && ![80, 443].include?(uri.port)
                           "#{uri.scheme}://#{uri.host}:#{uri.port}"
                         else
                           "#{uri.scheme}://#{uri.host}"
                         end

            HeadlessBrowserTool::Logger.log.info "Step 1: Navigating to domain URL: #{domain_url}"
            # First navigate to the domain (this might set new cookies)
            capybara_session.visit(domain_url)

            # Restore cookies if present
            if state["cookies"] && !state["cookies"].empty?
              HeadlessBrowserTool::Logger.log.info "Step 2: Deleting all cookies that were just set"
              # Delete all cookies that were just set
              capybara_session.driver.browser.manage.delete_all_cookies

              HeadlessBrowserTool::Logger.log.info "Step 3: Restoring #{state["cookies"].length} saved cookies"
              # Now add back our saved cookies
              restore_cookies(capybara_session, state["cookies"])

              # Log current cookies after restoration
              current_cookies = capybara_session.driver.browser.manage.all_cookies
              HeadlessBrowserTool::Logger.log.info "Cookies after restoration: #{current_cookies.length}"
              HeadlessBrowserTool::Logger.log.info "Cookie names: #{current_cookies.map { |c| c[:name] }.join(", ")}"
            end

            HeadlessBrowserTool::Logger.log.info "Step 4: Restoring localStorage and sessionStorage"
            # Restore storage BEFORE refresh so everything is in place
            if state["local_storage"] && !state["local_storage"].empty?
              HeadlessBrowserTool::Logger.log.info "  - Restoring #{state["local_storage"].length} localStorage items"
              restore_storage(capybara_session, "localStorage", state["local_storage"])
            end

            if state["session_storage"] && !state["session_storage"].empty?
              HeadlessBrowserTool::Logger.log.info "  - Restoring #{state["session_storage"].length} sessionStorage items"
              restore_storage(capybara_session, "sessionStorage", state["session_storage"])
            end

            HeadlessBrowserTool::Logger.log.info "Step 5: Refreshing page to activate restored session"
            # CRITICAL: Refresh the page AFTER restoring everything (cookies + storage)
            # This ensures the page has all the data it needs to show logged-in state
            capybara_session.refresh

            # Log cookies after refresh
            current_cookies_after = capybara_session.driver.browser.manage.all_cookies
            HeadlessBrowserTool::Logger.log.info "Cookies after refresh: #{current_cookies_after.length}"
            HeadlessBrowserTool::Logger.log.info "Cookie names after refresh: #{current_cookies_after.map { |c| c[:name] }.join(", ")}"

            HeadlessBrowserTool::Logger.log.info "Session restoration completed successfully"
          rescue StandardError => e
            HeadlessBrowserTool::Logger.log.info "ERROR during restoration: #{e.message}"
            HeadlessBrowserTool::Logger.log.info "Backtrace: #{e.backtrace.first(5).join("\n  ")}"
          end
        end

        # Restore window size - handle errors gracefully since window might be closed
        if state["window_size"]
          begin
            HeadlessBrowserTool::Logger.log.info "Restoring window size: #{state["window_size"]["width"]}x#{state["window_size"]["height"]}"
            capybara_session.current_window.resize_to(
              state["window_size"]["width"],
              state["window_size"]["height"]
            )
          rescue Selenium::WebDriver::Error::NoSuchWindowError => e
            # Window resize can fail if window was closed - this is not a corrupted session
            HeadlessBrowserTool::Logger.log.info "Could not restore window size (window closed): #{e.message}"
          end
        end

        HeadlessBrowserTool::Logger.log.info "=== Session restoration completed for: #{session_id} ==="
        true
      rescue StandardError => e
        HeadlessBrowserTool::Logger.log.info "ERROR restoring session: #{e.message}"
        HeadlessBrowserTool::Logger.log.info "Backtrace: #{e.backtrace.first(5).join("\n  ")}"

        # Only delete session file for actual corruption/parsing errors, not browser state issues
        if e.is_a?(JSON::ParserError)
          begin
            File.delete(session_file)
            HeadlessBrowserTool::Logger.log.info "Deleted corrupted session file (invalid JSON)"
          rescue StandardError
            nil
          end
        else
          HeadlessBrowserTool::Logger.log.info "Keeping session file - error was not due to corruption"
        end
        false
      end
    end

    def session_exists?(session_id)
      File.exist?(File.join(DirectorySetup::SESSIONS_DIR, "#{session_id}.json"))
    end

    def delete_session(session_id)
      session_file = File.join(DirectorySetup::SESSIONS_DIR, "#{session_id}.json")
      FileUtils.rm_f(session_file)
    end

    def extract_cookies(session)
      session.driver.browser.manage.all_cookies
    rescue StandardError => e
      HeadlessBrowserTool::Logger.log.info "Error extracting cookies: #{e.message}"
      []
    end

    def extract_storage(session, storage_type)
      return {} if BLANK_URLS.include?(session.current_url)
      return {} if session.current_url.start_with?("data:")

      session.evaluate_script(<<~JS)
        (() => {
          const items = {};
          for (let i = 0; i < #{storage_type}.length; i++) {
            const key = #{storage_type}.key(i);
            items[key] = #{storage_type}.getItem(key);
          }
          return items;
        })()
      JS
    rescue StandardError => e
      HeadlessBrowserTool::Logger.log.info "Error extracting #{storage_type}: #{e.message}"
      {}
    end

    def extract_window_size(session)
      size = session.current_window.size
      { "width" => size[0], "height" => size[1] }
    rescue StandardError => e
      HeadlessBrowserTool::Logger.log.info "Error extracting window size: #{e.message}"
      nil
    end

    def restore_cookies(session, cookies)
      return if cookies.nil? || cookies.empty?

      successfully_restored = 0
      failed_cookies = []

      cookies.each do |cookie|
        cookie_hash = cookie.transform_keys(&:to_sym)
        original_name = cookie_hash[:name]

        # Convert expires string to Time object if present
        if cookie_hash[:expires]
          begin
            cookie_hash[:expires] = Time.parse(cookie_hash[:expires])
          rescue StandardError => e
            HeadlessBrowserTool::Logger.log.debug "  WARNING: Failed to parse expiry for cookie '#{original_name}': #{e.message}"
            # If parsing fails, remove the expires field
            cookie_hash.delete(:expires)
          end
        end

        # Remove browser-specific fields that can't be set
        cookie_hash.delete(:same_site)
        cookie_hash.delete(:http_only)

        begin
          session.driver.browser.manage.add_cookie(cookie_hash)
          successfully_restored += 1
        rescue StandardError => e
          HeadlessBrowserTool::Logger.log.debug "  Failed to restore cookie '#{original_name}': #{e.message}"
          failed_cookies << original_name
        end
      end

      HeadlessBrowserTool::Logger.log.info "Restored #{successfully_restored}/#{cookies.length} cookies"
      HeadlessBrowserTool::Logger.log.info "Failed cookies: #{failed_cookies.join(", ")}" unless failed_cookies.empty?
    rescue StandardError => e
      HeadlessBrowserTool::Logger.log.info "CRITICAL ERROR restoring cookies: #{e.message}"
      HeadlessBrowserTool::Logger.log.info "Backtrace: #{e.backtrace.first(3).join("\n  ")}"
    end

    def restore_storage(session, storage_type, storage_data)
      return if storage_data.nil? || storage_data.empty? || BLANK_URLS.include?(session.current_url)
      return if session.current_url.start_with?("data:")

      storage_data.each do |key, value|
        session.execute_script("#{storage_type}.setItem(#{key.to_json}, #{value.to_json})")
      end
    rescue StandardError => e
      HeadlessBrowserTool::Logger.log.info "Error restoring #{storage_type}: #{e.message}"
    end
  end
end
