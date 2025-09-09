# frozen_string_literal: true

require_relative "base_tool"

module HeadlessBrowserTool
  module Tools
    class ClickLinkTool < BaseTool
      tool_name "click_link"
      description "Click link by text or selector"

      arguments do
        required(:link_text_or_selector).filled(:string).description("Link text or CSS selector")
      end

      def execute(link_text_or_selector:)
        url_before = browser.current_url
        browser.title

        # Find the link element first
        link = begin
          browser.find_link(link_text_or_selector)
        rescue Capybara::ElementNotFound
          browser.find(link_text_or_selector)
        end

        link_info = {
          text: link.text.strip,
          href: link[:href],
          target: link[:target]
        }.compact

        browser.click_link(link_text_or_selector)

        {
          link: link_text_or_selector,
          element: link_info,
          navigation: {
            navigated: browser.current_url != url_before,
            from: url_before,
            to: browser.current_url,
            title: browser.title
          },
          status: "success"
        }
      end
    end
  end
end
