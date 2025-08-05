# frozen_string_literal: true

require_relative "base_tool"

module HeadlessBrowserTool
  module Tools
    class SearchSourceTool < BaseTool
      tool_name "search_source"
      description "Search the page's HTML source code"

      arguments do
        required(:query).filled(:string).description("Text or regex pattern to search for")
        optional(:case_sensitive).filled(:bool)
                                 .description("Whether the search should be case sensitive (default: false)")
        optional(:regex).filled(:bool).description("Treat query as regex pattern (default: false)")
        optional(:context_lines).filled(:integer).description("Number of lines to show around matches (default: 2)")
        optional(:show_line_numbers).filled(:bool).description("Show line numbers in results (default: true)")
      end

      def execute(query:, case_sensitive: false, regex: false, context_lines: 2, show_line_numbers: true)
        # Get page source
        source = browser.get_page_source
        lines = source.split("\n")

        # Build search pattern
        pattern = if regex
                    Regexp.new(query, case_sensitive ? nil : Regexp::IGNORECASE)
                  else
                    escaped_query = Regexp.escape(query)
                    Regexp.new(escaped_query, case_sensitive ? nil : Regexp::IGNORECASE)
                  end

        # Find all matches with line context
        matches = []
        lines.each_with_index do |line, index|
          next unless line =~ pattern

          # Get context lines
          start_idx = [0, index - context_lines].max
          end_idx = [lines.length - 1, index + context_lines].min

          # Build match entry
          match_entry = {
            line_number: index + 1,
            line: line,
            match_count: line.scan(pattern).size
          }

          # Add context with line numbers
          if context_lines.positive?
            context_before = []
            context_after = []

            (start_idx...index).each do |i|
              context_line = show_line_numbers ? "#{i + 1}: #{lines[i]}" : lines[i]
              context_before << context_line
            end

            ((index + 1)..end_idx).each do |i|
              context_line = show_line_numbers ? "#{i + 1}: #{lines[i]}" : lines[i]
              context_after << context_line
            end

            match_entry[:context] = {
              before: context_before,
              after: context_after
            }
          end

          # Highlight matches in the line
          highlighted_line = line.gsub(pattern) { |match| ">>#{match}<<" }
          match_entry[:highlighted] = highlighted_line

          matches << match_entry
        end

        # Analyze match types
        match_analysis = analyze_matches(matches, lines, pattern)

        # Build result
        {
          query: query,
          total_matches: matches.sum { |m| m[:match_count] },
          total_lines_with_matches: matches.size,
          matches: matches.map do |match|
            result = {
              line_number: match[:line_number],
              line: match[:line].strip,
              highlighted: match[:highlighted].strip,
              occurrences: match[:match_count]
            }

            result[:context] = match[:context] if match[:context]

            result
          end,
          analysis: match_analysis
        }
      end

      private

      def analyze_matches(matches, _lines, pattern)
        analysis = {
          tags: {},
          attributes: {},
          scripts: 0,
          styles: 0,
          comments: 0,
          text_content: 0
        }

        matches.each do |match|
          line = match[:line]

          # Detect what type of content contains the match
          case line
          when /<script/i
            analysis[:scripts] += match[:match_count]
          when /<style/i
            analysis[:styles] += match[:match_count]
          when /<!--/
            analysis[:comments] += match[:match_count]
          when /<(\w+)[^>]*>/
            tag_name = ::Regexp.last_match(1).downcase
            analysis[:tags][tag_name] ||= 0
            analysis[:tags][tag_name] += match[:match_count]

            # Check if match is in an attribute
            # Use the pattern to check for attribute matches
            line.scan(/(\w+)=["'][^"']*/) do |attr_match|
              attr_name = attr_match[0].downcase
              attr_value = ::Regexp.last_match(0)
              if attr_value =~ pattern
                analysis[:attributes][attr_name] ||= 0
                analysis[:attributes][attr_name] += 1
              end
            end
          else
            analysis[:text_content] += match[:match_count] if line !~ /^\s*</
          end
        end

        analysis
      end
    end
  end
end
