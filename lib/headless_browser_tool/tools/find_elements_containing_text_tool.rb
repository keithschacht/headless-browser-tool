# frozen_string_literal: true

require_relative "base_tool"

module HeadlessBrowserTool
  module Tools
    class FindElementsContainingTextTool < BaseTool
      tool_name "find_elements_containing_text"
      description "Find all elements containing specified text and return their selectors"

      arguments do
        required(:text).filled(:string).description("Text to search for in elements")
        optional(:exact_match).filled(:bool).description("Require exact text match (default: false)")
        optional(:case_sensitive).filled(:bool).description("Case sensitive search (default: false)")
        optional(:visible_only).filled(:bool).description("Only return visible elements (default: true)")
      end

      def execute(text:, exact_match: false, case_sensitive: false, visible_only: true)
        script = build_search_script(text, exact_match, case_sensitive, visible_only)
        elements_data = browser.execute_script(script)

        # Ensure we have an array to work with
        elements_data = [] if elements_data.nil?
        elements_data = [elements_data] unless elements_data.is_a?(Array)

        # Process and enrich the results
        results = elements_data.map do |element|
          # Skip if element is not a hash
          next unless element.is_a?(Hash)

          # Safely extract values with defaults
          {
            tag: element["tag"] || "unknown",
            text: (element["text"] || "").to_s,
            selector: element["selector"] || "",
            xpath: element["xpath"] || "",
            attributes: element["attributes"] || {},
            parent: element["parent"] || nil,
            clickable: element["clickable"] == true,
            visible: element["visible"] == true,
            position: element["position"] || {}
          }
        end.compact

        {
          query: text,
          total_found: results.size,
          elements: results
        }
      end

      private

      def build_search_script(text, exact_match, case_sensitive, visible_only)
        <<~JS
          (function() {
            const searchText = #{text.to_json};
            const exactMatch = #{exact_match};
            const caseSensitive = #{case_sensitive};
            const visibleOnly = #{visible_only};

            // Helper to check if element is visible
            function isVisible(elem) {
              if (!elem) return false;
              const style = window.getComputedStyle(elem);
              return style.display !== 'none' &&
                     style.visibility !== 'hidden' &&
                     style.opacity !== '0' &&
                     elem.offsetWidth > 0 &&
                     elem.offsetHeight > 0;
            }

            // Helper to generate unique selector
            function getSelector(elem) {
              if (elem.id) {
                return '#' + CSS.escape(elem.id);
              }

              if (elem.className && typeof elem.className === 'string') {
                const classes = elem.className.trim().split(/\\s+/)
                  .filter(c => c.length > 0)
                  .map(c => '.' + CSS.escape(c))
                  .join('');
                if (classes && document.querySelectorAll(elem.tagName + classes).length === 1) {
                  return elem.tagName.toLowerCase() + classes;
                }
              }

              // Build path from root
              const path = [];
              let current = elem;
              while (current && current.nodeType === Node.ELEMENT_NODE) {
                let selector = current.tagName.toLowerCase();
                if (current.id) {
                  selector = '#' + CSS.escape(current.id);
                  path.unshift(selector);
                  break;
                } else {
                  let sibling = current;
                  let nth = 1;
                  while (sibling.previousElementSibling) {
                    sibling = sibling.previousElementSibling;
                    if (sibling.tagName === current.tagName) nth++;
                  }
                  if (nth > 1) selector += ':nth-of-type(' + nth + ')';
                }
                path.unshift(selector);
                current = current.parentElement;
              }
              return path.join(' > ');
            }

            // Helper to get XPath
            function getXPath(elem) {
              const path = [];
              let current = elem;
              while (current && current.nodeType === Node.ELEMENT_NODE) {
                let index = 0;
                let sibling = current;
                while (sibling) {
                  if (sibling.nodeType === Node.ELEMENT_NODE && sibling.tagName === current.tagName) {
                    index++;
                  }
                  sibling = sibling.previousSibling;
                  if (sibling === current) break;
                }
                path.unshift(current.tagName.toLowerCase() + '[' + index + ']');
                current = current.parentElement;
              }
              return '//' + path.join('/');
            }

            // Helper to check if text matches
            function textMatches(elementText, searchText) {
              if (!caseSensitive) {
                elementText = elementText.toLowerCase();
                searchText = searchText.toLowerCase();
              }

              if (exactMatch) {
                return elementText.trim() === searchText.trim();
              } else {
                return elementText.includes(searchText);
              }
            }

            // Helper to check if element is clickable
            function isClickable(elem) {
              const tag = elem.tagName.toLowerCase();
              return tag === 'a' || tag === 'button' ||
                     elem.onclick !== null ||
                     elem.hasAttribute('onclick') ||
                     elem.style.cursor === 'pointer' ||
                     elem.role === 'button' ||
                     elem.role === 'link';
            }

            // Find all text nodes and their parent elements
            const results = [];
            const processed = new Set();
            const walker = document.createTreeWalker(
              document.body,
              NodeFilter.SHOW_TEXT,
              {
                acceptNode: function(node) {
                  if (node.textContent.trim().length === 0) {
                    return NodeFilter.FILTER_REJECT;
                  }
                  return NodeFilter.FILTER_ACCEPT;
                }
              }
            );

            let node;
            while (node = walker.nextNode()) {
              const parent = node.parentElement;
              if (!parent || processed.has(parent)) continue;

              const text = parent.textContent;
              if (textMatches(text, searchText)) {
                if (visibleOnly && !isVisible(parent)) continue;

                processed.add(parent);

                // Get element attributes
                const attributes = {};
                if (parent.attributes && parent.attributes.length) {
                  for (let i = 0; i < parent.attributes.length; i++) {
                    const attr = parent.attributes[i];
                    attributes[attr.name] = attr.value;
                  }
                }

                // Get position
                const rect = parent.getBoundingClientRect();

                results.push({
                  tag: parent.tagName.toLowerCase(),
                  text: text.trim().substring(0, 200), // Limit text length
                  selector: getSelector(parent),
                  xpath: getXPath(parent),
                  attributes: attributes,
                  parent: parent.parentElement ? parent.parentElement.tagName.toLowerCase() : null,
                  clickable: isClickable(parent),
                  visible: isVisible(parent),
                  position: {
                    top: rect.top + window.scrollY,
                    left: rect.left + window.scrollX,
                    width: rect.width,
                    height: rect.height
                  }
                });
              }
            }

            // Also search in input values
            document.querySelectorAll('input, textarea, select').forEach(elem => {
              if (processed.has(elem)) return;

              const value = elem.value || elem.textContent;
              if (value && textMatches(value, searchText)) {
                if (visibleOnly && !isVisible(elem)) return;

                const attributes = {};
                if (elem.attributes && elem.attributes.length) {
                  for (let i = 0; i < elem.attributes.length; i++) {
                    const attr = elem.attributes[i];
                    attributes[attr.name] = attr.value;
                  }
                }

                const rect = elem.getBoundingClientRect();

                results.push({
                  tag: elem.tagName.toLowerCase(),
                  text: value.trim().substring(0, 200),
                  selector: getSelector(elem),
                  xpath: getXPath(elem),
                  attributes: attributes,
                  parent: elem.parentElement ? elem.parentElement.tagName.toLowerCase() : null,
                  clickable: true,
                  visible: isVisible(elem),
                  position: {
                    top: rect.top + window.scrollY,
                    left: rect.left + window.scrollX,
                    width: rect.width,
                    height: rect.height
                  }
                });
              }
            });

            return results;
          })();
        JS
      end
    end
  end
end
