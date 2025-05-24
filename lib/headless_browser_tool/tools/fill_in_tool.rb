# frozen_string_literal: true

require_relative "base_tool"

module HeadlessBrowserTool
  module Tools
    class FillInTool < BaseTool
      tool_name "fill_in"
      description "Fill in an input field"

      arguments do
        required(:field).filled(:string).description("Field name, id, or label")
        required(:value).filled(:string).description("Value to fill in")
      end

      def execute(field:, value:)
        # Try to find the field to get more info
        field_info = begin
          # Try different selectors
          element = begin
            browser.find_element("input[name='#{field}']")
          rescue StandardError
            nil
          end
          element ||= begin
            browser.find_element("input##{field}")
          rescue StandardError
            nil
          end
          element ||= begin
            browser.find_element("textarea[name='#{field}']")
          rescue StandardError
            nil
          end
          element ||= begin
            browser.find_element("textarea##{field}")
          rescue StandardError
            nil
          end

          if element
            {
              type: element[:attributes]["type"] || "text",
              name: element[:attributes]["name"],
              id: element[:attributes]["id"],
              placeholder: element[:attributes]["placeholder"]
            }.compact
          else
            {}
          end
        rescue StandardError
          {}
        end

        browser.fill_in(field, value)

        {
          field: field,
          value: value,
          field_info: field_info,
          status: "success"
        }
      end
    end
  end
end
