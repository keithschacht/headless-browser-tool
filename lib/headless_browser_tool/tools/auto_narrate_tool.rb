# frozen_string_literal: true

require_relative "base_tool"

module HeadlessBrowserTool
  module Tools
    class AutoNarrateTool < BaseTool
      tool_name "auto_narrate"
      description "Enable automatic narration of what's happening on the page"

      arguments do
        optional(:enabled).filled(:bool).description("Enable or disable auto-narration")
      end

      def execute(enabled: true)
        if enabled
          inject_narration_script
          "Auto-narration enabled. Browser will now describe significant events."
        else
          disable_narration
          "Auto-narration disabled."
        end
      end

      private

      def inject_narration_script
        script = <<~JS
          (() => {
            // Store narration state
            window.__aiNarration = window.__aiNarration || [];

            const narrate = (message) => {
              const timestamp = new Date().toISOString();
              window.__aiNarration.push({ timestamp, message });
              console.log(`[AI Narration] ${message}`);

              // Keep only last 50 events
              if (window.__aiNarration.length > 50) {
                window.__aiNarration.shift();
              }
            };

            // Monitor page changes
            const observer = new MutationObserver((mutations) => {
              const significantChanges = [];

              mutations.forEach((mutation) => {
                // New nodes added
                if (mutation.type === 'childList' && mutation.addedNodes.length > 0) {
                  Array.from(mutation.addedNodes).forEach((node) => {
                    if (node.nodeType === 1) { // Element node
                      if (node.tagName === 'DIV' && node.classList.contains('modal')) {
                        significantChanges.push('A modal dialog appeared');
                      } else if (node.tagName === 'FORM') {
                        significantChanges.push('A new form appeared on the page');
                      } else if (node.classList && node.classList.contains('error')) {
                        significantChanges.push(`Error message: "${node.textContent.trim()}"`);
                      } else if (node.classList && node.classList.contains('success')) {
                        significantChanges.push(`Success message: "${node.textContent.trim()}"`);
                      }
                    }
                  });
                }

                // Attributes changed
                if (mutation.type === 'attributes') {
                  if (mutation.attributeName === 'disabled') {
                    const element = mutation.target;
                    if (element.tagName === 'BUTTON' || element.tagName === 'INPUT') {
                      const action = element.disabled ? 'disabled' : 'enabled';
                      significantChanges.push(`${element.tagName} "${element.textContent || element.value}" was ${action}`);
                    }
                  }
                }
              });

              // Narrate significant changes
              significantChanges.forEach(narrate);
            });

            // Start observing
            observer.observe(document.body, {
              childList: true,
              attributes: true,
              subtree: true,
              attributeFilter: ['disabled', 'hidden', 'style']
            });

            // Monitor form submissions
            document.addEventListener('submit', (e) => {
              const form = e.target;
              const formName = form.id || form.name || 'unnamed form';
              narrate(`Form "${formName}" is being submitted`);
            }, true);

            // Monitor clicks
            document.addEventListener('click', (e) => {
              const target = e.target;
              if (target.tagName === 'BUTTON' || target.tagName === 'A') {
                const text = target.textContent.trim();
                if (text) {
                  narrate(`Clicked on "${text}"`);
                }
              }
            }, true);

            // Monitor page visibility
            document.addEventListener('visibilitychange', () => {
              narrate(document.hidden ? 'Page became hidden' : 'Page became visible');
            });

            // Monitor AJAX requests
            const originalFetch = window.fetch;
            window.fetch = function(...args) {
              const url = args[0];
              narrate(`Making request to: ${url}`);
              return originalFetch.apply(this, args)
                .then(response => {
                  narrate(`Request completed: ${response.status} ${response.statusText}`);
                  return response;
                })
                .catch(error => {
                  narrate(`Request failed: ${error.message}`);
                  throw error;
                });
            };

            // Initial narration
            narrate(`Monitoring page: "${document.title}"`);

            // Function to get narration history
            window.getAINarration = () => window.__aiNarration;
          })();
        JS

        browser.execute_script(script)
      end

      def disable_narration
        script = <<~JS
          (() => {
            // Remove observers and restore original functions
            if (window.__aiNarrationObserver) {
              window.__aiNarrationObserver.disconnect();
            }
            window.__aiNarration = [];
          })();
        JS

        browser.execute_script(script)
      end
    end
  end
end
