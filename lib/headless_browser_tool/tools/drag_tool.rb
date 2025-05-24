# frozen_string_literal: true

require_relative "base_tool"

module HeadlessBrowserTool
  module Tools
    class DragTool < BaseTool
      tool_name "drag"
      description "Drag an element to another element"

      arguments do
        required(:source_selector).filled(:string).description("CSS selector of the element to drag")
        required(:target_selector).filled(:string).description("CSS selector of the target element")
      end

      def execute(source_selector:, target_selector:)
        source = browser.find(source_selector)
        target = browser.find(target_selector)

        source_info = {
          tag_name: source.tag_name,
          text: source.text.strip,
          id: source[:id],
          class: source[:class]
        }.compact

        target_info = {
          tag_name: target.tag_name,
          text: target.text.strip,
          id: target[:id],
          class: target[:class]
        }.compact

        browser.drag(source_selector, target_selector)

        {
          source_selector: source_selector,
          target_selector: target_selector,
          source: source_info,
          target: target_info,
          status: "dragged"
        }
      end
    end
  end
end
