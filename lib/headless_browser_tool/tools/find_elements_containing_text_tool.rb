# frozen_string_literal: true

require_relative "base_tool"

module HeadlessBrowserTool
  module Tools
    class FindElementsContainingTextTool < BaseTool
      tool_name "find_elements_containing_text"
      description "Find all elements containing specified text and return their selectors"

      arguments do
        required(:text).filled(:string).description("Text to search for in elements")
        optional(:case_sensitive).filled(:bool).description("Case sensitive search (default: false)")
        optional(:visible_only).filled(:bool).description("Only return visible elements (default: true)")
      end

      def execute(text:, case_sensitive: false, visible_only: true)
        script = build_search_script(text, case_sensitive, visible_only)
        elements_data = browser.evaluate_script(script)

        # Check if JavaScript returned an error object
        if elements_data.is_a?(Hash) && elements_data["error"]
          return {
            error: "JavaScript error during search: #{elements_data["error"]}",
            query: text,
            total_found: 0,
            elements: []
          }
        end

        # Ensure we have an array to work with
        elements_data = [] if elements_data.nil?
        elements_data = [elements_data] unless elements_data.is_a?(Array)

        # Process and enrich the results
        results = elements_data.map do |element|
          # Skip if element is not a hash
          next unless element.is_a?(Hash)

          # Skip if this is an error object
          next if element["error"]

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
      rescue Selenium::WebDriver::Error::JavascriptError => e
        {
          error: "JavaScript error: #{e.message}",
          query: text,
          total_found: 0,
          elements: []
        }
      rescue StandardError => e
        {
          error: "Failed to search for elements: #{e.message}",
          query: text,
          total_found: 0,
          elements: []
        }
      end

      private

      def build_search_script(text, case_sensitive, visible_only)
        <<~JS
          (function() {
            try {
              const searchText = #{text.to_json};
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

            // Helper to check if element is directly clickable
            function isDirectlyClickable(elem) {
              const tag = elem.tagName.toLowerCase();
              // Check common clickable elements
              if (tag === 'a' || tag === 'button' ||#{" "}
                  tag === 'input' || tag === 'select' ||#{" "}
                  tag === 'textarea' || tag === 'label') {
                return true;
              }
              // Check for click handlers or role attributes
              if (elem.onclick !== null ||
                  elem.hasAttribute('onclick') ||
                  elem.style.cursor === 'pointer' ||
                  elem.role === 'button' ||
                  elem.role === 'link' ||
                  elem.role === 'tab' ||
                  elem.hasAttribute('tabindex')) {
                return true;
              }
              return false;
            }

            // Helper to check if element is clickable (including ancestors)
            function isClickable(elem) {
              // Check the element itself
              if (isDirectlyClickable(elem)) return true;
          #{"    "}
              // Check ancestors up to body
              let parent = elem.parentElement;
              while (parent && parent !== document.body) {
                if (isDirectlyClickable(parent)) return true;
                parent = parent.parentElement;
              }
              return false;
            }

            // Main search logic using XPath to find direct text containers
            const results = [];
            const processed = new Set();
          #{"  "}
            // Prepare search text for XPath
            const searchTextLower = caseSensitive ? searchText : searchText.toLowerCase();
          #{"  "}
            // Walk through all elements and check if they directly contain the search text
            const allElements = document.getElementsByTagName('*');
          #{"  "}
            for (let elem of allElements) {
              // Skip if already processed
              if (processed.has(elem)) continue;
          #{"    "}
              // Skip script and style elements
              if (elem.tagName === 'SCRIPT' || elem.tagName === 'STYLE' || elem.tagName === 'NOSCRIPT') continue;
          #{"    "}
              // Check if element's direct text (not from children) contains search text
              let directText = '';
              let hasDirectText = false;
              for (let node of elem.childNodes) {
                if (node.nodeType === Node.TEXT_NODE) {
                  directText += node.textContent;
                  if (node.textContent.trim().length > 0) {
                    hasDirectText = true;
                  }
                }
              }
          #{"    "}
              // Skip if no direct text
              if (!hasDirectText) continue;
          #{"    "}
              // Check text match
              const textToCheck = caseSensitive ? directText : directText.toLowerCase();
              if (!textToCheck.includes(searchTextLower)) continue;
          #{"    "}
              // Check visibility if required
              if (visibleOnly && !isVisible(elem)) continue;
          #{"    "}
              // Add to processed set
              processed.add(elem);

              // Get element attributes
              const attributes = {};
              if (elem.attributes && elem.attributes.length) {
                for (let i = 0; i < elem.attributes.length; i++) {
                  const attr = elem.attributes[i];
                  attributes[attr.name] = attr.value;
                }
              }

              // Get position
              const rect = elem.getBoundingClientRect();

              results.push({
                tag: elem.tagName.toLowerCase(),
                text: elem.textContent.trim().substring(0, 200), // Full text content, limited
                selector: getSelector(elem),
                xpath: getXPath(elem),
                attributes: attributes,
                parent: elem.parentElement ? elem.parentElement.tagName.toLowerCase() : null,
                clickable: isClickable(elem),
                visible: isVisible(elem),
                position: {
                  top: rect.top + window.scrollY,
                  left: rect.left + window.scrollX,
                  width: rect.width,
                  height: rect.height
                }
              });
            }

            // Also search in input/textarea values
            document.querySelectorAll('input, textarea').forEach(elem => {
              if (processed.has(elem)) return;

              const value = elem.value;
              if (!value) return;
          #{"    "}
              const valueToCheck = caseSensitive ? value : value.toLowerCase();
              if (!valueToCheck.includes(searchTextLower)) return;
          #{"    "}
              if (visibleOnly && !isVisible(elem)) return;

              processed.add(elem);
          #{"    "}
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
                clickable: true, // Input elements are always clickable
                visible: isVisible(elem),
                position: {
                  top: rect.top + window.scrollY,
                  left: rect.left + window.scrollX,
                  width: rect.width,
                  height: rect.height
                }
              });
            });

            // Also check for elements with text in specific attributes
            const attributesToCheck = ['placeholder', 'title', 'aria-label', 'alt'];
            attributesToCheck.forEach(attrName => {
              const attrSelector = '[' + attrName + ']';
              document.querySelectorAll(attrSelector).forEach(elem => {
                if (processed.has(elem)) return;
          #{"      "}
                const attrValue = elem.getAttribute(attrName);
                if (!attrValue) return;
          #{"      "}
                const valueToCheck = caseSensitive ? attrValue : attrValue.toLowerCase();
                if (!valueToCheck.includes(searchTextLower)) return;
          #{"      "}
                if (visibleOnly && !isVisible(elem)) return;
          #{"      "}
                processed.add(elem);
          #{"      "}
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
                  text: (elem.textContent || attrValue).trim().substring(0, 200),
                  selector: getSelector(elem),
                  xpath: getXPath(elem),
                  attributes: attributes,
                  parent: elem.parentElement ? elem.parentElement.tagName.toLowerCase() : null,
                  clickable: isClickable(elem),
                  visible: isVisible(elem),
                  position: {
                    top: rect.top + window.scrollY,
                    left: rect.left + window.scrollX,
                    width: rect.width,
                    height: rect.height
                  }
                });
              });
            });

              return results;
            } catch(e) {
              return { error: e.toString(), stack: e.stack };
            }
          })();
        JS
      end
    end
  end
end
