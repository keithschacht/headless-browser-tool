# frozen_string_literal: true

require_relative "base_tool"

module HeadlessBrowserTool
  module Tools
    class ScrollToTool < BaseTool
      tool_name "scroll_to"
      description "Scroll to an element on the page"

      arguments do
        required(:selector).filled(:string).description("CSS selector of the element to scroll to")
      end

      def execute(selector:)
        element = browser.find(selector)

        initial_scroll_position = browser.evaluate_script("window.pageYOffset")

        # Use JavaScript to find and scroll to the element by selector
        # This works with both CDP and regular Selenium modes
        escaped_selector = selector.gsub("'", "\\\\'")
        browser.execute_script("const el = document.querySelector('#{escaped_selector}'); if (el) { el.scrollIntoView({ behavior: 'instant', block: 'start' }); }")

        sleep 0.1

        final_scroll_position = browser.evaluate_script("window.pageYOffset")
        
        # Get element rect using selector instead of element reference
        element_rect = browser.evaluate_script("const el = document.querySelector('#{escaped_selector}'); return el ? el.getBoundingClientRect() : null;")

        {
          selector: selector,
          element: {
            tag_name: element.tag_name,
            text: element.text.strip[0..100],
            id: element[:id],
            class: element[:class]
          }.compact,
          scroll: {
            initial_position: initial_scroll_position,
            final_position: final_scroll_position,
            scrolled: initial_scroll_position != final_scroll_position
          },
          element_position: {
            top: element_rect["top"],
            left: element_rect["left"],
            in_viewport: element_rect["top"] >= 0 && element_rect["top"] < browser.evaluate_script("window.innerHeight")
          },
          status: "scrolled"
        }
      rescue Capybara::ElementNotFound
        {
          status: "error",
          error: "Unable to find element with selector: #{selector}",
          selector: selector
        }
      rescue Selenium::WebDriver::Error::InvalidSelectorError
        {
          status: "error",
          error: "Invalid CSS selector: #{selector}",
          selector: selector
        }
      rescue StandardError => e
        {
          status: "error",
          error: "Failed to scroll to element: #{e.message}",
          selector: selector
        }
      end
    end
  end
end
