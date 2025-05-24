# frozen_string_literal: true

require_relative "base_tool"

module HeadlessBrowserTool
  module Tools
    class SelectTool < BaseTool
      tool_name "select"
      description "Select an option from a dropdown"

      arguments do
        required(:value).filled(:string).description("Value or text to select")
        required(:dropdown_selector).filled(:string).description("CSS selector of the dropdown")
      end

      def execute(value:, dropdown_selector:)
        dropdown = browser.find(dropdown_selector)

        # Get all options
        options = dropdown.all("option").map.with_index do |opt, index|
          {
            selector: "#{dropdown_selector} option:nth-of-type(#{index + 1})",
            value: opt.value,
            text: opt.text,
            selected: opt.selected?
          }
        end

        browser.select(value, dropdown_selector)

        # Find the newly selected option
        selected_option = dropdown.all("option").find(&:selected?)

        {
          dropdown_selector: dropdown_selector,
          selected_value: selected_option&.value,
          selected_text: selected_option&.text,
          options: options,
          status: "selected"
        }
      end
    end
  end
end
