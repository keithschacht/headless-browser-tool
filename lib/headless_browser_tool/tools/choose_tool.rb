# frozen_string_literal: true

require_relative "base_tool"

module HeadlessBrowserTool
  module Tools
    class ChooseTool < BaseTool
      tool_name "choose"
      description "Select a radio button by selector"

      arguments do
        required(:radio_button_selector).filled(:string).description("CSS selector of the radio button to select")
      end

      def execute(radio_button_selector:)
        radio = browser.find(radio_button_selector)

        # Get radio group info
        name = radio[:name]
        radio_group = browser.all("input[type='radio'][name='#{name}']") if name

        radio_info = {
          id: radio[:id],
          name: name,
          value: radio[:value],
          was_checked: radio.checked?
        }.compact

        browser.choose(radio_button_selector)

        # Get all radio buttons in the same group
        group_info = radio_group&.map&.with_index do |r, index|
          selector = if r[:id] && !r[:id].empty?
                       "##{r[:id]}"
                     else
                       "input[type='radio'][name='#{name}']:nth-of-type(#{index + 1})"
                     end

          {
            selector: selector,
            value: r[:value],
            checked: r.checked?,
            id: r[:id]
          }.compact
        end

        {
          selector: radio_button_selector,
          radio: radio_info,
          group: group_info,
          status: "selected"
        }
      end
    end
  end
end
