# frozen_string_literal: true

module HeadlessBrowserTool
  module StealthMode
    def inject_stealth_js(session)
      # This JavaScript will be executed on every page to hide automation indicators
      stealth_js = <<~JS
        // Hide webdriver property
        Object.defineProperty(navigator, 'webdriver', {
          get: () => undefined
        });

        // Remove automation indicators
        if (window.chrome) {
          window.chrome.runtime = undefined;
          Object.defineProperty(navigator, 'plugins', {
            get: () => [1, 2, 3, 4, 5]
          });
        }

        // Override permissions
        const originalQuery = window.navigator.permissions.query;
        window.navigator.permissions.query = (parameters) => (
          parameters.name === 'notifications' ?
            Promise.resolve({ state: Notification.permission }) :
            originalQuery(parameters)
        );
      JS

      # Execute on initial page
      begin
        session.execute_script(stealth_js) if session.current_url != "about:blank"
      rescue StandardError
        # Ignore errors on blank pages
      end
    end
  end
end