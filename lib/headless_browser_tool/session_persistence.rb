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
      return unless session_id && capybara_session

      FileUtils.mkdir_p(DirectorySetup::SESSIONS_DIR)
      session_file = File.join(DirectorySetup::SESSIONS_DIR, "#{session_id}.json")

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

        File.write(session_file, JSON.pretty_generate(state))
      rescue StandardError => e
        HeadlessBrowserTool::Logger.log.info "Error saving session: #{e.message}"
      end
    end

    def restore_session(session_id, capybara_session)
      session_file = File.join(DirectorySetup::SESSIONS_DIR, "#{session_id}.json")
      return unless File.exist?(session_file)

      begin
        state = JSON.parse(File.read(session_file))

        # Restore cookies if present
        # Selenium/Chrome requires navigating to the domain before setting cookies
        # But we want to avoid triggering new session creation
        if state["cookies"] && !state["cookies"].empty? && state["current_url"]
          begin
            uri = URI.parse(state["current_url"])
            domain_url = "#{uri.scheme}://#{uri.host}"
            
            # First navigate to the domain (this might set new cookies)
            capybara_session.visit(domain_url)
            
            # Delete all cookies that were just set
            capybara_session.driver.browser.manage.delete_all_cookies
            
            # Now add back our saved cookies
            restore_cookies(capybara_session, state["cookies"])
            
            # CRITICAL: Refresh the page so the restored cookies take effect
            # Without this, the page still thinks we're not logged in
            capybara_session.refresh
            
            # Also restore localStorage and sessionStorage after refresh
            # Some sites need these for authentication state
            if state["local_storage"] && !state["local_storage"].empty?
              restore_storage(capybara_session, "localStorage", state["local_storage"])
            end
            
            if state["session_storage"] && !state["session_storage"].empty?
              restore_storage(capybara_session, "sessionStorage", state["session_storage"])
            end
          rescue StandardError => e
            HeadlessBrowserTool::Logger.log.info "Error during cookie restoration: #{e.message}"
          end
        end

        # Restore window size
        if state["window_size"]
          capybara_session.current_window.resize_to(
            state["window_size"]["width"],
            state["window_size"]["height"]
          )
        end

        true
      rescue StandardError => e
        HeadlessBrowserTool::Logger.log.info "Error restoring session: #{e.message}"
        # Delete corrupted state file
        begin
          File.delete(session_file)
        rescue StandardError
          nil
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

      cookies.each do |cookie|
        cookie_hash = cookie.transform_keys(&:to_sym)

        # Convert expires string to Time object if present
        if cookie_hash[:expires]
          begin
            cookie_hash[:expires] = Time.parse(cookie_hash[:expires])
          rescue StandardError
            # If parsing fails, remove the expires field
            cookie_hash.delete(:expires)
          end
        end

        # Remove browser-specific fields that can't be set
        cookie_hash.delete(:same_site)
        cookie_hash.delete(:http_only)

        session.driver.browser.manage.add_cookie(cookie_hash)
      end
    rescue StandardError => e
      HeadlessBrowserTool::Logger.log.info "Error restoring cookies: #{e.message}"
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
