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

        # Get element info before clicking
        element = browser.find_element(selector)
        element_text = element[:text]
        tag_name = element[:tag_name]

        # Perform click
        browser.click(selector)

        # Brief wait to allow page changes
        sleep 0.1

        {
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
      end
    end
  end
end
