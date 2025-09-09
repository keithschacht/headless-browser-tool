# frozen_string_literal: true

require_relative "base_tool"

module HeadlessBrowserTool
  module Tools
    class FindElementTool < BaseTool
      tool_name "find_element"
      description "Find single element, errors if not found"

      arguments do
        required(:selector).filled(:string).description("CSS selector of the element to find")
      end

      def execute(selector:)
        element = browser.find(selector)
        
        # Get the element's tag name
        tag_name = element.tag_name
        
        # Build the opening HTML tag with all attributes
        opening_tag = build_opening_tag(element, tag_name)
        
        # Format the result with two lines
        result_string = "Found element: #{selector}\n#{opening_tag}"
        
        {
          status: "success",
          result: result_string
        }
      end

      private

      def build_opening_tag(element, tag_name)
        # Start with the tag name
        tag_parts = ["<#{tag_name}"]
        
        # Use JavaScript to get the outerHTML and extract just the opening tag
        outer_html = browser.evaluate_script("arguments[0].outerHTML", element)
        
        if outer_html
          # Extract just the opening tag (everything before the first > or />)
          if match = outer_html.match(/^<[^>]+>/)
            return match[0]
          end
        end
        
        # Fallback: build tag manually using common attributes
        # This should rarely be needed but provides a safety net
        common_attrs = %w[id class href src alt title name type value placeholder 
                         data-testid role aria-label data-action required disabled
                         checked selected readonly autocomplete maxlength minlength
                         pattern step min max width height style rel target method
                         action enctype for tabindex lang dir contenteditable draggable
                         spellcheck hidden]
        
        common_attrs.each do |attr|
          value = element[attr]
          if value && !value.to_s.empty?
            # Escape quotes in the attribute value
            escaped_value = value.to_s.gsub('"', '&quot;')
            tag_parts << "#{attr}=\"#{escaped_value}\""
          end
        end
        
        # Close the opening tag
        tag_parts.join(" ") + ">"
      end
    end
  end
end