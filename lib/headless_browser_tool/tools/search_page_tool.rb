# frozen_string_literal: true

require_relative "base_tool"

module HeadlessBrowserTool
  module Tools
    class SearchPageTool < BaseTool
      tool_name "search_page"
      description "Search for text or patterns in the current page content"

      arguments do
        required(:query).filled(:string).description("Text or regex pattern to search for")
        optional(:case_sensitive).filled(:bool)
                                 .description("Whether the search should be case sensitive (default: false)")
        optional(:regex).filled(:bool).description("Treat query as regex pattern (default: false)")
        optional(:context_lines).filled(:integer).description("Number of lines to show around matches (default: 2)")
        optional(:highlight).filled(:bool).description("Highlight matches in the browser (default: false)")
      end

      def execute(query:, case_sensitive: false, regex: false, context_lines: 2, highlight: false)
        # Get page text content
        page_text = browser.text
        lines = page_text.split("\n")

        # Build search pattern
        pattern = if regex
                    Regexp.new(query, case_sensitive ? nil : Regexp::IGNORECASE)
                  else
                    escaped_query = Regexp.escape(query)
                    Regexp.new(escaped_query, case_sensitive ? nil : Regexp::IGNORECASE)
                  end

        # Find matches with line numbers
        matches = []
        lines.each_with_index do |line, index|
          next unless line =~ pattern

          match_info = {
            line_number: index + 1,
            line: line,
            matches: line.scan(pattern)
          }

          # Add context
          if context_lines.positive?
            start_idx = [0, index - context_lines].max
            end_idx = [lines.length - 1, index + context_lines].min
            match_info[:context] = {
              before: lines[start_idx...index],
              after: lines[(index + 1)..end_idx]
            }
          end

          matches << match_info
        end

        # Highlight in browser if requested
        if highlight && matches.any?
          highlight_script = build_highlight_script(query, regex, case_sensitive)
          browser.execute_script(highlight_script)
        end

        # Build result
        result = {
          query: query,
          total_matches: matches.size,
          matches: matches.map do |match|
            output = {
              line_number: match[:line_number],
              line: match[:line].strip,
              occurrences: match[:matches].size
            }

            if match[:context]
              output[:context] = {
                before: match[:context][:before].map(&:strip),
                after: match[:context][:after].map(&:strip)
              }
            end

            output
          end
        }

        # Also search in HTML attributes and hidden text if no matches in visible text
        if matches.empty?
          html_matches = search_html(pattern)
          result[:html_matches] = html_matches if html_matches.any?
        end

        result
      end

      private

      def search_html(pattern)
        # Search in page source for hidden content, attributes, etc.
        page_source = browser.html
        matches = []

        # Search in common attributes
        attribute_patterns = [
          /<[^>]+\s+(?:title|alt|placeholder|aria-label|data-[^=]+)="([^"]*#{pattern}[^"]*)"/i,
          /<[^>]+\s+(?:href|src|action)="([^"]*#{pattern}[^"]*)"/i,
          /<meta[^>]+content="([^"]*#{pattern}[^"]*)"/i
        ]

        attribute_patterns.each do |attr_pattern|
          page_source.scan(attr_pattern) do |match|
            matches << {
              type: "attribute",
              content: match[0],
              context: ::Regexp.last_match(0)[0..200] # First 200 chars of the matching element
            }
          end
        end

        # Search in script tags
        page_source.scan(%r{<script[^>]*>(.*?)</script>}mi) do |script_content|
          if script_content[0] =~ pattern
            matches << {
              type: "script",
              content: script_content[0][0..200],
              match_count: script_content[0].scan(pattern).size
            }
          end
        end

        matches
      end

      def build_highlight_script(query, regex, case_sensitive)
        <<~JS
          (function() {
            // Remove any existing highlights
            document.querySelectorAll('.hbt-search-highlight').forEach(el => {
              const parent = el.parentNode;
              parent.replaceChild(document.createTextNode(el.textContent), el);
              parent.normalize();
            });

            // Add highlight styles
            if (!document.getElementById('hbt-search-styles')) {
              const style = document.createElement('style');
              style.id = 'hbt-search-styles';
              style.textContent = `
                .hbt-search-highlight {
                  background-color: yellow;
                  color: black;
                  font-weight: bold;
                  padding: 0 2px;
                  border-radius: 2px;
                }
              `;
              document.head.appendChild(style);
            }

            // Create search pattern
            const flags = #{case_sensitive ? "'g'" : "'gi'"};
            const pattern = #{regex ? "new RegExp('#{query.gsub("'", "\\\\'")}')" : "new RegExp('#{Regexp.escape(query).gsub("'", "\\\\'")}')"} + ', ' + flags + ')';

            // Function to highlight text nodes
            function highlightTextNode(textNode) {
              const text = textNode.textContent;
              const matches = text.matchAll(pattern);
              const matchArray = Array.from(matches);

              if (matchArray.length > 0) {
                const fragment = document.createDocumentFragment();
                let lastIndex = 0;

                matchArray.forEach(match => {
                  // Add text before match
                  if (match.index > lastIndex) {
                    fragment.appendChild(
                      document.createTextNode(text.substring(lastIndex, match.index))
                    );
                  }

                  // Add highlighted match
                  const span = document.createElement('span');
                  span.className = 'hbt-search-highlight';
                  span.textContent = match[0];
                  fragment.appendChild(span);

                  lastIndex = match.index + match[0].length;
                });

                // Add remaining text
                if (lastIndex < text.length) {
                  fragment.appendChild(
                    document.createTextNode(text.substring(lastIndex))
                  );
                }

                textNode.parentNode.replaceChild(fragment, textNode);
              }
            }

            // Walk through all text nodes
            function walkTextNodes(node) {
              if (node.nodeType === Node.TEXT_NODE) {
                highlightTextNode(node);
              } else if (node.nodeType === Node.ELEMENT_NODE &&
                         !['SCRIPT', 'STYLE', 'NOSCRIPT'].includes(node.tagName)) {
                for (let child of Array.from(node.childNodes)) {
                  walkTextNodes(child);
                }
              }
            }

            walkTextNodes(document.body);

            // Scroll to first match
            const firstHighlight = document.querySelector('.hbt-search-highlight');
            if (firstHighlight) {
              firstHighlight.scrollIntoView({ behavior: 'smooth', block: 'center' });
            }
          })();
        JS
      end
    end
  end
end
