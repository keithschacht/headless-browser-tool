# frozen_string_literal: true

require_relative "test_helper"
require "json"
require "open3"
require "timeout"

class TestMCPProtocolIntegration < Minitest::Test
  def setup
    @session_id = "test-mcp-#{Time.now.to_i}"
  end

  def test_mcp_stdio_protocol_call_method
    # This test verifies that FastMCP can successfully call our tools
    # The fix adds a 'call' method that delegates to 'execute'
    
    # Create a simple MCP request to visit a URL
    request = {
      jsonrpc: "2.0",
      id: 1,
      method: "tools/call",
      params: {
        name: "visit",
        arguments: {
          url: "https://www.example.com"
        }
      }
    }

    # Start the stdio server and send the request
    output, error, status = Open3.capture3(
      { "HBT_SESSION_ID" => @session_id },
      "bundle", "exec", "hbt", "stdio",
      stdin_data: "#{request.to_json}\n"
    )

    # Parse the response
    response_lines = output.split("\n").select { |line| line.strip.start_with?("{") }
    
    assert response_lines.any?, "Server failed to return valid JSON response. Error: #{error}"
    
    response = JSON.parse(response_lines.first)
    
    # The request should now succeed
    assert response["result"], "Expected successful result"
    refute response["result"]["isError"], "Should not be an error response"
    
    # Verify the tool returned expected data
    result_content = response["result"]["content"]
    assert result_content, "Expected content in response"
    
    # The visit tool returns the result as a Ruby hash stringified
    # We need to check if it's JSON or a Ruby hash string
    text_content = result_content.first["text"]
    
    # Check if the response indicates success
    assert_match(/url.*https:\/\/www\.example\.com/, text_content)
    assert_match(/status.*success/, text_content)
  end

  def test_tools_have_both_call_and_execute
    # Verify that our tools now have both methods
    tool = HeadlessBrowserTool::Tools::VisitTool.new
    
    assert_respond_to tool, :execute, "Tool should have execute method"
    assert_respond_to tool, :call, "Tool should now have call method (delegating to execute)"
  end
end