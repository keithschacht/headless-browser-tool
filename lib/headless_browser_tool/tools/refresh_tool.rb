# frozen_string_literal: true

require_relative "base_tool"

module HeadlessBrowserTool
  module Tools
    class RefreshTool < BaseTool
      tool_name "refresh"
      description "Reload the current page"

      def execute
        url_before = browser.current_url
        title_before = browser.title

        browser.refresh

        # Brief wait for refresh to complete
        sleep 0.1

        {
          url: browser.current_url,
          title: browser.title,
          changed: {
            url: url_before != browser.current_url,
            title: title_before != browser.title
          },
          status: "success"
        }
      end
    end
  end
end
