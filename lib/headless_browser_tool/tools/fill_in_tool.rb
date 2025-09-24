# frozen_string_literal: true

require_relative "base_tool"
require "capybara"

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

        # Attempt to fill in the field - this will raise an error if field doesn't exist
        begin
          browser.fill_in(field, value)

          {
            field: field,
            value: value,
            field_info: field_info,
            status: "success"
          }
        rescue Capybara::ElementNotFound => e
          # Field not found - return error status
          {
            field: field,
            value: value,
            field_info: {},
            status: "error",
            error: "Field not found",
            message: e.message
          }
        rescue StandardError => e
          # Other errors - return error status
          {
            field: field,
            value: value,
            field_info: field_info,
            status: "error",
            error: e.class.name,
            message: e.message
          }
        end
      end
    end
  end
end
