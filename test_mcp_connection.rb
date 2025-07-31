#!/usr/bin/env ruby

require 'net/http'
require 'json'
require 'uri'

# Test MCP server connection
uri = URI('http://localhost:4567/mcp')

puts "Testing MCP server connection..."
puts "=" * 50

# Test initialize
request = Net::HTTP::Post.new(uri)
request['Content-Type'] = 'application/json'
request.body = {
  jsonrpc: "2.0",
  method: "initialize",
  params: {
    protocolVersion: "2025-06-18",
    capabilities: { roots: {} },
    clientInfo: { name: "test-client", version: "1.0.0" }
  },
  id: 0
}.to_json

response = Net::HTTP.start(uri.hostname, uri.port) { |http| http.request(request) }
result = JSON.parse(response.body)
puts "Initialize response:"
puts JSON.pretty_generate(result)
puts

# Test tools/list
request.body = {
  jsonrpc: "2.0",
  method: "tools/list",
  params: {},
  id: 1
}.to_json

response = Net::HTTP.start(uri.hostname, uri.port) { |http| http.request(request) }
result = JSON.parse(response.body)
puts "Tools count: #{result['result']['tools'].length}"
puts "First 5 tools:"
result['result']['tools'][0..4].each do |tool|
  puts "  - #{tool['name']}: #{tool['description']}"
end

# Test a tool call
puts "\nTesting tool call (get_session_info)..."
request.body = {
  jsonrpc: "2.0",
  method: "tools/call",
  params: {
    name: "mcp__headless_browser__get_session_info",
    arguments: {}
  },
  id: 2
}.to_json

response = Net::HTTP.start(uri.hostname, uri.port) { |http| http.request(request) }
result = JSON.parse(response.body)
puts "Tool call response:"
puts JSON.pretty_generate(result)