# frozen_string_literal: true

require_relative "base_tool"

module HeadlessBrowserTool
  module Tools
    class RightClickTool < BaseTool
      tool_name "right_click"
      description "Right-click an element by CSS selector"

      arguments do
        required(:selector).filled(:string).description("CSS selector of the element to right-click")
      end

      def execute(selector:)
        element = browser.find(selector)
        element_info = {
          tag_name: element.tag_name,
          text: element.text.strip,
          visible: element.visible?,
          attributes: {
            id: element[:id],
            class: element[:class]
          }.compact
        }

        browser.right_click(selector)

        {
          selector: selector,
          element: element_info,
          status: "right_clicked"
        }
      end
    end
  end
end
