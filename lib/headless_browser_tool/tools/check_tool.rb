# frozen_string_literal: true

require_relative "base_tool"

module HeadlessBrowserTool
  module Tools
    class CheckTool < BaseTool
      tool_name "check"
      description "Check a checkbox by selector. If selector matches multiple elements, use index to specify which."

      arguments do
        required(:checkbox_selector).filled(:string).description("CSS selector of the checkbox to check")
        optional(:index).filled(:integer).description("Index of element if selector matches multiple (0-based)")
      end

      def execute(checkbox_selector:, index: nil)
        # Find all matching elements
        elements = browser.all(checkbox_selector, visible: true)

        # Check if element exists
        if elements.empty?
          return {
            status: "error",
            error: "Element #{checkbox_selector} not found"
          }
        end

        # Handle ambiguous selector
        if elements.size > 1 && index.nil?
          return {
            status: "error",
            error: "Ambiguous selector - found #{elements.size} elements matching: #{checkbox_selector}"
          }
        end

        # Validate index if provided
        if !index.nil? && (index.negative? || index >= elements.size)
          return {
            status: "error",
            error: "Invalid index #{index} for #{elements.size} elements matching: #{checkbox_selector}"
          }
        end

        # Select the appropriate element
        element_index = index || 0
        element = elements[element_index]

        # Build JS selector for evaluate_script
        js_selector = if elements.size == 1
                        "document.querySelector('#{escape_js_string(checkbox_selector)}')"
                      else
                        "document.querySelectorAll('#{escape_js_string(checkbox_selector)}')[#{element_index}]"
                      end

        # Check if element is a checkbox
        is_checkbox = browser.evaluate_script("#{js_selector}.checked")
        if is_checkbox.nil?
          return {
            status: "error",
            error: "Element #{checkbox_selector} is not a checkbox"
          }
        end

        # Check current state
        was_checked = is_checkbox

        # If already checked, return success
        if was_checked
          result = {
            selector: checkbox_selector,
            was_checked: was_checked,
            is_checked: true,
            element: {
              id: element[:id],
              name: element[:name],
              value: element[:value],
              type: element[:type]
            }.compact,
            status: "success"
          }
          result[:index] = index unless index.nil?
          return result
        end

        # Click to check
        element.click

        # Brief wait for state change
        sleep 0.1

        # Verify it's now checked
        is_now_checked = browser.evaluate_script("#{js_selector}.checked")

        unless is_now_checked
          return {
            status: "error",
            error: "Clicked element #{checkbox_selector} but it did not change to checked state"
          }
        end

        result = {
          selector: checkbox_selector,
          was_checked: was_checked,
          is_checked: true,
          element: {
            id: element[:id],
            name: element[:name],
            value: element[:value],
            type: element[:type]
          }.compact,
          status: "success"
        }
        result[:index] = index unless index.nil?
        result
      end

      private

      def escape_js_string(str)
        str.gsub("'", "\\\\'").gsub('"', '\\"')
      end
    end
  end
end

