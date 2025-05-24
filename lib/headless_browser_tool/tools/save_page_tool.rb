# frozen_string_literal: true

require_relative "base_tool"

module HeadlessBrowserTool
  module Tools
    class SavePageTool < BaseTool
      tool_name "save_page"
      description "Save the current page HTML"

      arguments do
        required(:file_path).filled(:string).description("Path where to save the HTML")
      end

      def execute(file_path:)
        # Ensure directory exists
        FileUtils.mkdir_p(File.dirname(file_path))

        browser.save_page(file_path)

        {
          file_path: file_path,
          file_size: File.size(file_path),
          timestamp: Time.now.iso8601,
          url: browser.current_url,
          title: browser.title,
          status: "saved"
        }
      end
    end
  end
end
