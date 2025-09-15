# frozen_string_literal: true

require_relative "base_tool"

module HeadlessBrowserTool
  module Tools
    class ClickTool < BaseTool
      tool_name "click"
      description "Click an element by text or CSS selector. Automatically tries multiple strategies " \
                  "to find buttons, links, or any clickable element."

      arguments do
        required(:text_or_selector).filled(:string).description("Text content or CSS selector of the element to click")
        optional(:index).filled(:integer).description("which index in the array of elements matches (for ambiguous selectors)")
      end

      def execute(text_or_selector:, index: nil)
        # Capture state before click
        url_before = browser.current_url

        # Try multiple strategies to find the element
        element = nil
        strategy_used = nil

        # Strategy 1: Try as CSS selector first (if it looks like one)
        if looks_like_css_selector?(text_or_selector)
          result = try_css_selector(text_or_selector, index)
          if result[:error]
            return {
              status: result[:status],
              error: result[:message],
              text_or_selector: result[:text_or_selector],
              index: result[:index]
            }.compact
          end

          element = result[:element]
          strategy_used = result[:strategy]
        end

        # Strategy 2: Try as button text
        if element.nil?
          begin
            element = browser.find_button(text_or_selector)
            strategy_used = "button_text"
          rescue Capybara::ElementNotFound, Capybara::Ambiguous
            # Continue to next strategy
          end
        end

        # Strategy 3: Try as link text
        if element.nil?
          begin
            element = browser.find_link(text_or_selector)
            strategy_used = "link_text"
          rescue Capybara::ElementNotFound, Capybara::Ambiguous
            # Continue to next strategy
          end
        end

        # Strategy 4: Try finding any clickable element containing the text
        if element.nil?
          result = try_clickable_text(text_or_selector, index)
          if result[:error]
            return {
              status: result[:status],
              error: result[:message],
              text_or_selector: result[:text_or_selector],
              elements: result[:elements]
            }.compact
          end

          element = result[:element]
          strategy_used = result[:strategy] if result[:element]
        end

        # Strategy 5: Last resort - try as a plain CSS selector without visibility check
        if element.nil? && !text_or_selector.match?(/^[a-zA-Z0-9\s]+$/)
          begin
            element = browser.find(text_or_selector)
            strategy_used = "css_fallback"
          rescue Capybara::ElementNotFound, Capybara::Ambiguous
            # Will handle below
          end
        end

        # If we still haven't found anything, return an error
        if element.nil?
          return {
            status: "error",
            error: "Unable to find clickable element with text or selector: #{text_or_selector}",
            text_or_selector: text_or_selector
          }
        end

        # Gather element information
        element_text = element.text.strip
        tag_name = element.tag_name
        is_disabled = begin
          element.disabled?
        rescue StandardError
          false
        end

        # Build element info based on tag type
        element_info = {
          tag_name: tag_name,
          text: element_text
        }

        # Add relevant attributes based on element type
        case tag_name
        when "a"
          element_info[:href] = element[:href] if element[:href]
          element_info[:target] = element[:target] if element[:target]
        when "button", "input"
          element_info[:type] = element[:type] if element[:type]
          element_info[:value] = element[:value] if element[:value]
          element_info[:disabled] = true if is_disabled
        end

        # Perform click on the element
        element.click

        # Brief wait to allow page changes
        sleep 0.1

        result = {
          status: "success",
          text_or_selector: text_or_selector,
          strategy: strategy_used,
          element: element_info.compact,
          navigation: {
            url_before: url_before,
            url_after: browser.current_url,
            navigated: url_before != browser.current_url
          }
        }

        # Add index if it was used
        result[:index] = index if index && strategy_used.include?("indexed")

        result
      rescue Capybara::ElementNotFound
        {
          status: "error",
          error: "Unable to find element with text or selector: #{text_or_selector}",
          text_or_selector: text_or_selector
        }
      rescue Capybara::Ambiguous => e
        # Extract the number of elements found from the error message
        match_count = e.message[/found (\d+)/, 1] || "multiple"
        {
          status: "error",
          error: "Ambiguous text or selector - found #{match_count} elements matching: #{text_or_selector}",
          text_or_selector: text_or_selector
        }
      rescue Selenium::WebDriver::Error::ElementNotInteractableError
        {
          status: "error",
          error: "Element is not interactable (may be hidden or disabled): #{text_or_selector}",
          text_or_selector: text_or_selector
        }
      rescue Selenium::WebDriver::Error::InvalidSelectorError
        {
          status: "error",
          error: "Invalid CSS selector: #{text_or_selector}",
          text_or_selector: text_or_selector
        }
      rescue StandardError => e
        {
          status: "error",
          error: "Failed to click element: #{e.message}",
          text_or_selector: text_or_selector
        }
      end

      private

      def looks_like_css_selector?(text)
        text.include?("#") || text.include?(".") || text.include?("[") || text.include?(">")
      end

      def try_css_selector(text_or_selector, index)
        elements = browser.all(text_or_selector, visible: true)
        return { element: nil, strategy: nil } unless elements.any?

        return handle_single_element(elements.first, index, text_or_selector) if elements.size == 1

        handle_multiple_elements(elements, index, text_or_selector)
      end

      def handle_single_element(element, index, text_or_selector)
        # For single element, only index 0 or nil is valid
        if !index.nil? && index != 0
          return {
            error: true,
            status: "error",
            message: "Invalid index #{index} for 1 elements matching: #{text_or_selector}",
            text_or_selector: text_or_selector,
            index: index
          }
        end
        { element: element, strategy: "css_selector" }
      end

      def handle_multiple_elements(elements, index, text_or_selector)
        if index.nil?
          return {
            error: true,
            status: "error",
            message: "Ambiguous text or selector - found #{elements.size} elements matching: #{text_or_selector}",
            text_or_selector: text_or_selector
          }
        end

        if index.negative? || index >= elements.size
          return {
            error: true,
            status: "error",
            message: "Invalid index #{index} for #{elements.size} elements matching: #{text_or_selector}",
            text_or_selector: text_or_selector,
            index: index
          }
        end

        { element: elements[index], strategy: "css_selector_indexed" }
      end

      def try_clickable_text(text_or_selector, index)
        clickable_selectors = ["button", "a", "[role='button']", "[onclick]", "input[type='submit']", "input[type='button']"]

        clickable_selectors.each do |selector|
          elements = browser.all(selector, text: text_or_selector, visible: true)
          next unless elements.any?

          result = process_clickable_elements(elements, text_or_selector, index)
          return result if result[:element] || result[:error]
        end

        { element: nil, strategy: nil }
      end

      def process_clickable_elements(elements, text_or_selector, index)
        return { element: elements.first, strategy: "text_in_clickable" } if elements.size == 1

        return { element: elements[index], strategy: "text_in_clickable_indexed" } if index && index >= 0 && index < elements.size

        return { element: nil, strategy: nil } unless index.nil?

        # Try to be smart about it - prefer exact text match
        exact_match = elements.find { |e| e.text.strip == text_or_selector }
        if exact_match
          { element: exact_match, strategy: "exact_text_match" }
        else
          {
            error: true,
            status: "error",
            message: "Found #{elements.size} clickable elements containing '#{text_or_selector}'. Please specify an index.",
            text_or_selector: text_or_selector,
            elements: elements.map.with_index { |e, i| { index: i, text: e.text.strip, tag: e.tag_name } }
          }
        end
      end
    end
  end
end
