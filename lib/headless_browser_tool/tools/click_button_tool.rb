# frozen_string_literal: true

require_relative "base_tool"

module HeadlessBrowserTool
  module Tools
    class ClickButtonTool < BaseTool
      tool_name "click_button"
      description "Click button by text or selector"

      arguments do
        required(:button_text_or_selector).filled(:string).description("Button text or CSS selector")
      end

      def execute(button_text_or_selector:)
        url_before = browser.current_url
        browser.title

        # Find the button element first
        button = begin
          browser.find_button(button_text_or_selector)
        rescue Capybara::ElementNotFound
          browser.find(button_text_or_selector)
        end

        button_info = {
          text: button.text.strip,
          value: button[:value],
          type: button[:type],
          disabled: button.disabled?
        }.compact

        browser.click_button(button_text_or_selector)

        {
          button: button_text_or_selector,
          element: button_info,
          navigation: {
            navigated: browser.current_url != url_before,
            from: url_before,
            to: browser.current_url,
            title: browser.title
          },
          status: "clicked"
        }
      rescue Capybara::ElementNotFound
        {
          status: "error",
          error: "Unable to find button: #{button_text_or_selector}",
          button: button_text_or_selector
        }
      rescue Capybara::Ambiguous => e
        # Extract the number of elements found from the error message
        match_count = e.message[/found (\d+)/, 1] || "multiple"
        {
          status: "error",
          error: "Ambiguous button selector - found #{match_count} elements matching: #{button_text_or_selector}",
          button: button_text_or_selector
        }
      rescue Selenium::WebDriver::Error::ElementNotInteractableError
        {
          status: "error",
          error: "Button is not interactable (may be hidden or disabled): #{button_text_or_selector}",
          button: button_text_or_selector
        }
      rescue Selenium::WebDriver::Error::InvalidSelectorError
        {
          status: "error",
          error: "Invalid selector: #{button_text_or_selector}",
          button: button_text_or_selector
        }
      rescue StandardError => e
        {
          status: "error",
          error: "Failed to click button: #{e.message}",
          button: button_text_or_selector
        }
      end
    end
  end
end
