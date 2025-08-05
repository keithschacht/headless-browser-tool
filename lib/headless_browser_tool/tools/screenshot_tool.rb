# frozen_string_literal: true

require_relative "base_tool"
require_relative "../directory_setup"
require "time"

module HeadlessBrowserTool
  module Tools
    class ScreenshotTool < BaseTool
      tool_name "screenshot"
      description "Take a screenshot of the current page"

      arguments do
        optional(:filename).filled(:string).description("Filename for the screenshot (auto-generated if not provided)")
        optional(:highlight_selectors).array(:string).description("CSS selectors to highlight in red boxes")
        optional(:annotate).filled(:bool).description("Add element annotations with data-testid and common selectors")
        optional(:full_page).filled(:bool).description("Capture entire page instead of just viewport (default: false)")
      end

      def execute(filename: nil, highlight_selectors: [], annotate: false, full_page: false)
        screenshots_dir = HeadlessBrowserTool::DirectorySetup::SCREENSHOTS_DIR
        timestamp = Time.now.strftime("%Y%m%d_%H%M%S_%L")

        # Generate filename with timestamp
        if filename
          # Remove .png extension if present to add timestamp before it
          base_name = filename.sub(/\.png$/i, "")
          filename = "#{base_name}_#{timestamp}.png"
        else
          filename = "screenshot_#{timestamp}.png"
        end

        file_path = File.join(screenshots_dir, filename)

        # Inject JavaScript to highlight elements
        inject_highlight_script(highlight_selectors, annotate) if highlight_selectors.any? || annotate

        # Take screenshot
        if full_page
          take_full_page_screenshot(file_path)
        else
          browser.save_screenshot(file_path)
        end

        # Remove highlights
        browser.execute_script("document.querySelectorAll('.ai-highlight').forEach(el => el.remove());")

        # Get file info
        file_size = File.size(file_path)

        {
          file_path: file_path,
          filename: filename,
          file_size: file_size,
          file_size_human: "#{(file_size / 1024.0).round(2)} KB",
          timestamp: timestamp,
          full_page: full_page,
          highlighted_elements: highlight_selectors.size,
          annotated: annotate,
          url: browser.current_url,
          title: browser.title
        }
      end

      private

      def take_full_page_screenshot(file_path)
        # Get the full page dimensions
        dimensions = browser.execute_script(<<~JS)
          return {
            width: Math.max(
              document.body.scrollWidth,
              document.body.offsetWidth,
              document.documentElement.clientWidth,
              document.documentElement.scrollWidth,
              document.documentElement.offsetWidth
            ),
            height: Math.max(
              document.body.scrollHeight,
              document.body.offsetHeight,
              document.documentElement.clientHeight,
              document.documentElement.scrollHeight,
              document.documentElement.offsetHeight
            ),
            devicePixelRatio: window.devicePixelRatio || 1
          };
        JS

        # Handle nil dimensions
        if dimensions.nil?
          # Fallback to just taking a regular screenshot
          browser.save_screenshot(file_path)
          return
        end

        # Store original window size
        original_size = browser.current_window.size

        # Resize window to full page dimensions
        # Add some padding to ensure everything is captured
        browser.current_window.resize_to(
          (dimensions["width"] || 1280) + 100,
          (dimensions["height"] || 720) + 100
        )

        # Small delay to ensure resize is complete
        sleep 0.5

        # Take the screenshot
        browser.save_screenshot(file_path)

        # Restore original window size
        browser.current_window.resize_to(original_size[0], original_size[1])
      end

      def inject_highlight_script(selectors, annotate)
        script = <<~JS
          // Remove any existing highlights
          document.querySelectorAll('.ai-highlight').forEach(el => el.remove());

          // Add highlight styles
          const style = document.createElement('style');
          style.textContent = `
            .ai-highlight {
              position: absolute;
              border: 3px solid red;
              background: rgba(255, 0, 0, 0.1);
              pointer-events: none;
              z-index: 10000;
            }
            .ai-annotation {
              position: absolute;
              background: red;
              color: white;
              padding: 2px 6px;
              font-size: 12px;
              font-family: monospace;
              border-radius: 3px;
              z-index: 10001;
            }
          `;
          document.head.appendChild(style);

          // Highlight specific selectors
          #{selectors.map { |sel| highlight_selector(sel) }.join("\n")}

          // Annotate interactive elements if requested
          #{annotate ? annotate_elements : ""}
        JS

        browser.execute_script(script)
        sleep 0.1 # Give time for rendering
      end

      def highlight_selector(selector)
        <<~JS
          try {
            document.querySelectorAll('#{selector}').forEach((el, index) => {
              const rect = el.getBoundingClientRect();
              const highlight = document.createElement('div');
              highlight.className = 'ai-highlight';
              highlight.style.top = rect.top + window.scrollY + 'px';
              highlight.style.left = rect.left + window.scrollX + 'px';
              highlight.style.width = rect.width + 'px';
              highlight.style.height = rect.height + 'px';
              document.body.appendChild(highlight);
            });
          } catch(e) {}
        JS
      end

      def annotate_elements
        <<~JS
          // Find and annotate interactive elements
          const interactiveSelectors = ['button', 'a', 'input', 'select', 'textarea', '[onclick]', '[role="button"]'];
          let annotationIndex = 1;

          interactiveSelectors.forEach(selector => {
            document.querySelectorAll(selector).forEach(el => {
              if (el.offsetWidth > 0 && el.offsetHeight > 0) { // Only visible elements
                const rect = el.getBoundingClientRect();
                const annotation = document.createElement('div');
                annotation.className = 'ai-annotation';
                annotation.textContent = annotationIndex;
                annotation.style.top = rect.top + window.scrollY - 20 + 'px';
                annotation.style.left = rect.left + window.scrollX + 'px';

                // Store selector info
                el.setAttribute('data-ai-index', annotationIndex);

                document.body.appendChild(annotation);
                annotationIndex++;
              }
            });
          });
        JS
      end
    end
  end
end
