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
      end
    end
  end
end
