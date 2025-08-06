# frozen_string_literal: true

require_relative "base_tool"

module HeadlessBrowserTool
  module Tools
    class ClickTool < BaseTool
      tool_name "click"
      description "Click an element by CSS selector"

      arguments do
        required(:selector).filled(:string).description("CSS selector of the element to click")
      end

      def execute(selector:)
        # Capture state before click
        url_before = browser.current_url

        # Check for ambiguous selector first
        elements = browser.all(selector, visible: true)
        if elements.size > 1
          return {
            status: "error",
            error: "Ambiguous selector - found #{elements.size} elements matching: #{selector}",
            selector: selector
          }
        elsif elements.empty?
          return {
            status: "error",
            error: "Unable to find element with selector: #{selector}",
            selector: selector
          }
        end

        # Get element info before clicking
        element = elements.first
        element_text = element.text
        tag_name = element.tag_name
        is_disabled = begin
          element.disabled?
        rescue StandardError
          false
        end

        # Perform click
        browser.click(selector)

        # Brief wait to allow page changes
        sleep 0.1

        result = {
          selector: selector,
          element: {
            tag_name: tag_name,
            text: element_text
          },
          navigation: {
            url_before: url_before,
            url_after: browser.current_url,
            navigated: url_before != browser.current_url
          }
        }

        # Add disabled status if element was disabled
        result[:element][:disabled] = true if is_disabled

        result
      rescue Capybara::ElementNotFound
        {
          status: "error",
          error: "Unable to find element with selector: #{selector}",
          selector: selector
        }
      rescue Capybara::Ambiguous => e
        # Extract the number of elements found from the error message
        match_count = e.message[/found (\d+)/, 1] || "multiple"
        {
          status: "error",
          error: "Ambiguous selector - found #{match_count} elements matching: #{selector}",
          selector: selector
        }
      rescue Selenium::WebDriver::Error::ElementNotInteractableError
        {
          status: "error",
          error: "Element is not interactable (may be hidden or disabled): #{selector}",
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
          error: "Failed to click element: #{e.message}",
          selector: selector
        }
      end
    end
  end
end
