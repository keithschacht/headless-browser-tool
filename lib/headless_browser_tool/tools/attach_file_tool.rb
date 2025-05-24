# frozen_string_literal: true

require_relative "base_tool"

module HeadlessBrowserTool
  module Tools
    class AttachFileTool < BaseTool
      tool_name "attach_file"
      description "Upload file to file input field"

      arguments do
        required(:file_field_selector).filled(:string).description("CSS selector of the file input field")
        required(:file_path).filled(:string).description("Path to the file to upload")
      end

      def execute(file_field_selector:, file_path:)
        file_field = browser.find(file_field_selector)

        # Get file info
        file_name = File.basename(file_path)
        file_size = File.size(file_path) if File.exist?(file_path)

        browser.attach_file(file_field_selector, file_path)

        {
          field_selector: file_field_selector,
          file_path: file_path,
          file_name: file_name,
          file_size: file_size,
          field: {
            id: file_field[:id],
            name: file_field[:name],
            accept: file_field[:accept]
          }.compact,
          status: "attached"
        }
      end
    end
  end
end
