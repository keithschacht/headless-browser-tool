# frozen_string_literal: true

require_relative "base_tool"

module HeadlessBrowserTool
  module Tools
    class FindAllTool < BaseTool
      tool_name "find_all"
      description "Find all matching elements, returns array"

      arguments do
        required(:selector).filled(:string).description("CSS selector to find all matching elements")
      end

      def execute(selector:)
        elements = browser.find_all(selector)

        # Handle nil case - return empty array structure
        return { selector: selector, count: 0, elements: [] } if elements.nil?

        {
          selector: selector,
          count: elements.size,
          elements: elements.map.with_index do |element, index|
            result = {
              index: index,
              selector: "#{selector}:nth-of-type(#{index + 1})",
              tag_name: element[:tag_name],
              text: element[:text].strip,
              visible: element[:visible]
            }

            # Include attributes if present
            result[:attributes] = element[:attributes] unless element[:attributes].empty?

            # Include value for form elements
            result[:value] = element[:value] if element[:value] && !element[:value].empty?

            result
          end
        }
      end
    end
  end
end
