# frozen_string_literal: true

require_relative "base_tool"

module HeadlessBrowserTool
  module Tools
    class EvaluateScriptTool < BaseTool
      tool_name "evaluate_script"
      description "Run JavaScript and return the result"

      arguments do
        required(:javascript_code).filled(:string).description("JavaScript code to evaluate")
      end

      def execute(javascript_code:)
        result = browser.evaluate_script(javascript_code)
        {
          status: "success",
          result: result,
          type: result.class.name
        }
      rescue Selenium::WebDriver::Error::JavascriptError => e
        {
          status: "error",
          error: "JavaScript error: #{e.message}"
        }
      rescue StandardError => e
        {
          status: "error",
          error: "Failed to evaluate script: #{e.message}"
        }
      end
    end
  end
end
