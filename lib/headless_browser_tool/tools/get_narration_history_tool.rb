# frozen_string_literal: true

require_relative "base_tool"

module HeadlessBrowserTool
  module Tools
    class GetNarrationHistoryTool < BaseTool
      tool_name "get_narration_history"
      description "Get the history of narrated events since auto_narrate was enabled"

      def execute
        history = browser.evaluate_script("window.getAINarration ? window.getAINarration() : []")

        if history.nil? || history.empty?
          "No narration history available. Enable auto_narrate first."
        else
          format_history(history)
        end
      end

      private

      def format_history(history)
        output = ["🎬 Browser Event History:"]

        history.last(20).each do |event|
          time = Time.parse(event["timestamp"]).strftime("%H:%M:%S")
          output << "[#{time}] #{event["message"]}"
        end

        output.join("\n")
      end
    end
  end
end
