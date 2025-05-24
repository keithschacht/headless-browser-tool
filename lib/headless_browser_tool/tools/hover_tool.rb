# frozen_string_literal: true

require_relative "base_tool"

module HeadlessBrowserTool
  module Tools
    class HoverTool < BaseTool
      tool_name "hover"
      description "Hover over an element by CSS selector"

      arguments do
        required(:selector).filled(:string).description("CSS selector of the element to hover over")
      end

      def execute(selector:)
        element = browser.find(selector)
        element_info = {
          tag_name: element.tag_name,
          text: element.text.strip,
          visible: element.visible?,
          attributes: {
            id: element[:id],
            class: element[:class],
            title: element[:title]
          }.compact
        }

        browser.hover(selector)

        {
          selector: selector,
          element: element_info,
          status: "hovering"
        }
      end
    end
  end
end
