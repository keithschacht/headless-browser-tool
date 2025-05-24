# frozen_string_literal: true

require_relative "base_tool"

module HeadlessBrowserTool
  module Tools
    class GoForwardTool < BaseTool
      tool_name "go_forward"
      description "Navigate forward in browser history"

      def execute
        url_before = browser.current_url
        browser.title

        browser.go_forward

        {
          navigation: {
            from: url_before,
            to: browser.current_url,
            title: browser.title,
            navigated: browser.current_url != url_before
          },
          status: "navigated_forward"
        }
      end
    end
  end
end
