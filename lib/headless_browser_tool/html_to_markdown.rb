# frozen_string_literal: true

require 'nokogiri'

module HeadlessBrowserTool
  class HtmlToMarkdown
    INDENT = '  '                         # two-space list indent

    def self.convert(html)
      fragment = Nokogiri::HTML.fragment(html)
      out = fragment.children.map { |n| emit(n, 0, nil) }.join
      out.gsub(/\s+\n/, "\n")             # trim trailing spaces
         .gsub(/\n{3,}/, "\n\n")          # collapse blank lines
         .strip + "\n"
    end

    def self.emit(node, depth, list_ctx)
      return node.text                    if node.text?

      case node.name
      when 'strong', 'b'
        "**#{node.children.map { |c| emit(c, depth, list_ctx) }.join.strip}**"
      when 'a'
        text = node.children.map { |c| emit(c, depth, list_ctx) }.join.strip
        href = node['href'] || '#'
        "[#{text}](#{href})"
      when 'br'                           then "\n"
      when 'p', 'section', 'div'          then node.children.map { |c| emit(c, depth, list_ctx) }.join + "\n\n"
      when 'ul'                           then node.element_children.map { |li| emit(li, depth + 1, :ul) }.join
      when 'ol'                           then node.element_children.each_with_index.map { |li, i| emit(li, depth + 1, [:ol, i + 1]) }.join
      when 'li'
        bullet = list_ctx == :ul ? '*' : "#{list_ctx.last}."
        indent = INDENT * (depth - 1)
        content = node.children.map { |c| emit(c, depth, nil) }.join.strip
        "#{indent}#{bullet} #{content}\n"
      else
        node.children.map { |c| emit(c, depth, list_ctx) }.join
      end
    end
  end
end