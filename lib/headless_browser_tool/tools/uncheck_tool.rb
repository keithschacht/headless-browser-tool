# frozen_string_literal: true

require_relative "base_tool"

module HeadlessBrowserTool
  module Tools
    class UncheckTool < BaseTool
      tool_name "uncheck"
      description "Uncheck a checkbox by selector"

      arguments do
        required(:checkbox_selector).filled(:string).description("CSS selector of the checkbox to uncheck")
      end

      def execute(checkbox_selector:)
        element = browser.find(checkbox_selector)
        was_checked = element.checked?
        browser.uncheck(checkbox_selector)

        {
          selector: checkbox_selector,
          was_checked: was_checked,
          is_checked: false,
          element: {
            id: element[:id],
            name: element[:name],
            value: element[:value],
            type: element[:type]
          }.compact,
          status: "unchecked"
        }
      end
    end
  end
end
