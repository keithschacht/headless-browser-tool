# frozen_string_literal: true

require_relative "base_tool"

module HeadlessBrowserTool
  module Tools
    class VisitTool < BaseTool
      tool_name "visit"
      description "Navigate to a URL"

      arguments do
        required(:url).filled(:string).description("The URL to navigate to")
      end

      def execute(url:)
        browser.visit(url)

        {
          url: url,
          current_url: browser.current_url,
          title: browser.title,
          status: "success"
        }
      end
    end
  end
end
