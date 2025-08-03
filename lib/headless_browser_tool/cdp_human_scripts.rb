# frozen_string_literal: true

module HeadlessBrowserTool
  module CDPHumanScripts # rubocop:disable Metrics/ModuleLength
    class << self
      def chrome_script
        <<~JS
          if (window.chrome) {
            if (window.chrome.runtime) {
              delete window.chrome.runtime.id;
            }
          } else {
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
        JS
      end

      def plugins_script
        <<~JS
          Object.defineProperty(navigator, 'plugins', {
            get: () => {
              const plugins = #{pdf_plugins_data};
              plugins.length = 5;
              plugins.item = (i) => plugins[i] || null;
              plugins.namedItem = () => null;
              plugins.refresh = () => {};
              return plugins;
            }
          });
        JS
      end

      def pdf_plugins_data
        <<~JS.strip
          [
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
          ]
        JS
      end
    end
  end
end
