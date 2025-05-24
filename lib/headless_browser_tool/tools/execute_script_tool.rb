# frozen_string_literal: true

require_relative "base_tool"

module HeadlessBrowserTool
  module Tools
    class ExecuteScriptTool < BaseTool
      tool_name "execute_script"
      description "Run JavaScript without return value"

      arguments do
        required(:javascript_code).filled(:string).description("JavaScript code to execute")
      end

      def execute(javascript_code:)
        start_time = Time.now
        browser.execute_script(javascript_code)
        execution_time = Time.now - start_time

        {
          javascript_code: javascript_code,
          execution_time: execution_time,
          timestamp: Time.now.iso8601,
          status: "executed"
        }
      end
    end
  end
end
