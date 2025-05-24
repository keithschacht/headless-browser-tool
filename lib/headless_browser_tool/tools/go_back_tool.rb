# frozen_string_literal: true

require_relative "base_tool"

module HeadlessBrowserTool
  module Tools
    class GoBackTool < BaseTool
      tool_name "go_back"
      description "Navigate back in browser history"

      def execute
        url_before = browser.current_url
        browser.title

        browser.go_back

        {
          navigation: {
            from: url_before,
            to: browser.current_url,
            title: browser.title,
            navigated: browser.current_url != url_before
          },
          status: "navigated_back"
        }
      end
    end
  end
end
