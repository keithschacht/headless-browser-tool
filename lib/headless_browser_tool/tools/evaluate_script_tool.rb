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
          result: result,
          type: result.class.name
        }
      end
    end
  end
end
