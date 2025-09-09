# frozen_string_literal: true

require "json"
require_relative "base_tool"
require_relative "../session_persistence"

module HeadlessBrowserTool
  module Tools
    class SaveSessionTool < BaseTool
      tool_name "save_session"
      description "Save the browser's current session info (e.g. cookies) to disk to later reuse"

      def execute
        # Get the current browser instance
        browser_instance = browser

        # Extract the session_id and capybara_session
        session_id = if browser_instance.instance_variable_defined?(:@session_id)
                       # BrowserAdapter or Browser has @session_id
                       browser_instance.instance_variable_get(:@session_id)
                     else
                       # Fallback to thread-local storage or server session_id
                       Thread.current[:hbt_session_id] || HeadlessBrowserTool::Server.session_id
                     end

        # Get the Capybara session object
        capybara_session = if browser_instance.respond_to?(:session)
                             # BrowserAdapter or Browser might have @session
                             browser_instance.instance_variable_get(:@session) || browser_instance.session
                           else
                             browser_instance
                           end

        if session_id.nil? || session_id == "default"
          return {
            status: "error",
            error: "No session ID available - cannot save session without a session ID"
          }
        end

        begin
          HeadlessBrowserTool::Logger.log.info "Manually saving session with ID: #{session_id}"
          SessionPersistence.save_session(session_id, capybara_session)

          session_file = File.expand_path(File.join(HeadlessBrowserTool::DirectorySetup::SESSIONS_DIR, "#{session_id}.json"))

          # Read back the saved session to get details
          if File.exist?(session_file)
            state = JSON.parse(File.read(session_file))
            {
              status: "success",
              session_id: session_id,
              saved_at: state["saved_at"],
              current_url: state["current_url"],
              cookies_count: state["cookies"]&.length || 0,
              local_storage_items: state["local_storage"]&.length || 0,
              session_storage_items: state["session_storage"]&.length || 0,
              file_path: session_file
            }
          else
            {
              status: "success",
              session_id: session_id,
              message: "Session saved but file verification failed",
              file_path: session_file
            }
          end
        rescue StandardError => e
          HeadlessBrowserTool::Logger.log.info "Error saving session: #{e.message}"
          {
            status: "error",
            error: e.message,
            session_id: session_id
          }
        end
      end
    end
  end
end
