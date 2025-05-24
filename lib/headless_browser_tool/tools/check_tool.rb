# frozen_string_literal: true

require_relative "base_tool"

module HeadlessBrowserTool
  module Tools
    class CheckTool < BaseTool
      tool_name "check"
      description "Check a checkbox by selector"

      arguments do
        required(:checkbox_selector).filled(:string).description("CSS selector of the checkbox to check")
      end

      def execute(checkbox_selector:)
        element = browser.find(checkbox_selector)
        was_checked = element.checked?
        browser.check(checkbox_selector)

        {
          selector: checkbox_selector,
          was_checked: was_checked,
          is_checked: true,
          element: {
            id: element[:id],
            name: element[:name],
            value: element[:value],
            type: element[:type]
          }.compact,
          status: "checked"
        }
      end
    end
  end
end
