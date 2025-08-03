# frozen_string_literal: true

module HeadlessBrowserTool
  module StealthMode # rubocop:disable Metrics/ModuleLength
    def inject_stealth_js(session)
      # This JavaScript will be executed on every page to hide automation indicators
      stealth_js = <<~JS
        // Hide webdriver property
        Object.defineProperty(navigator, 'webdriver', {
          get: () => undefined
        });

        // Enhanced window.chrome spoofing - preserve existing chrome object if present
        if (window.chrome) {
          // Remove automation indicators but preserve version info
          if (window.chrome.runtime) {
            delete window.chrome.runtime.id;
          }
        } else {
          // Only create chrome object if it doesn't exist
          window.chrome = {
            runtime: {},
            app: {
              isInstalled: false,
              InstallState: {
                DISABLED: 'disabled',
                INSTALLED: 'installed',
                NOT_INSTALLED: 'not_installed'
              },
              RunningState: {
                CANNOT_RUN: 'cannot_run',
                READY_TO_RUN: 'ready_to_run',
                RUNNING: 'running'
              }
            },
            csi: () => {},
            loadTimes: () => ({
              requestTime: Date.now() / 1000,
              startLoadTime: Date.now() / 1000,
              commitLoadTime: Date.now() / 1000,
              finishDocumentLoadTime: Date.now() / 1000,
              finishLoadTime: Date.now() / 1000,
              firstPaintTime: Date.now() / 1000,
              firstPaintAfterLoadTime: 0,
              navigationType: 'Other',
              wasFetchedViaSpdy: false,
              wasNpnNegotiated: false,
              npnNegotiatedProtocol: '',
              wasAlternateProtocolAvailable: false,
              connectionInfo: 'http/1.1'
            })
          };
        }

        // Better plugin spoofing with realistic plugins
        Object.defineProperty(navigator, 'plugins', {
          get: () => {
            const plugins = [
              {
                name: 'PDF Viewer',
                description: 'Portable Document Format',
                filename: 'internal-pdf-viewer',
                length: 2,
                item: (i) => ({
                  type: i === 0 ? 'application/pdf' : 'text/pdf',
                  suffixes: 'pdf',
                  description: 'Portable Document Format'
                }),
                namedItem: () => null
              },
              {
                name: 'Chrome PDF Viewer',
                description: 'Portable Document Format',
                filename: 'internal-pdf-viewer',
                length: 2,
                item: (i) => ({
                  type: i === 0 ? 'application/pdf' : 'text/pdf',
                  suffixes: 'pdf',
                  description: 'Portable Document Format'
                }),
                namedItem: () => null
              },
              {
                name: 'Chromium PDF Viewer',
                description: 'Portable Document Format',
                filename: 'internal-pdf-viewer',
                length: 2,
                item: (i) => ({
                  type: i === 0 ? 'application/pdf' : 'text/pdf',
                  suffixes: 'pdf',
                  description: 'Portable Document Format'
                }),
                namedItem: () => null
              },
              {
                name: 'Microsoft Edge PDF Viewer',
                description: 'Portable Document Format',
                filename: 'internal-pdf-viewer',
                length: 2,
                item: (i) => ({
                  type: i === 0 ? 'application/pdf' : 'text/pdf',
                  suffixes: 'pdf',
                  description: 'Portable Document Format'
                }),
                namedItem: () => null
              },
              {
                name: 'WebKit built-in PDF',
                description: 'Portable Document Format',
                filename: 'internal-pdf-viewer',
                length: 2,
                item: (i) => ({
                  type: i === 0 ? 'application/pdf' : 'text/pdf',
                  suffixes: 'pdf',
                  description: 'Portable Document Format'
                }),
                namedItem: () => null
              }
            ];
            plugins.length = 5;
            plugins.item = (i) => plugins[i] || null;
            plugins.namedItem = () => null;
            plugins.refresh = () => {};
            return plugins;
          }
        });

        // Override permissions to be consistent
        const originalQuery = window.navigator.permissions.query;
        window.navigator.permissions.query = (parameters) => (
          parameters.name === 'notifications' ?
            Promise.resolve({ state: Notification.permission }) :
            originalQuery(parameters)
        );

        // Fix window dimensions for headless detection
        if (window.outerWidth === 0 && window.outerHeight === 0) {
          Object.defineProperty(window, 'outerWidth', {
            get: () => window.innerWidth
          });
          Object.defineProperty(window, 'outerHeight', {
            get: () => window.innerHeight + 74 // Account for browser chrome
          });
        }

        // Additional fixes for various detection methods
        Object.defineProperty(navigator, 'languages', {
          get: () => ['en-US', 'en']
        });

        Object.defineProperty(navigator, 'platform', {
          get: () => 'MacIntel'
        });

        // Don't override userAgent or userAgentData - let Chrome handle it naturally!
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
