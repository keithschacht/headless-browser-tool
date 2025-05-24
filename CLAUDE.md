# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Quick Start for Development

When making changes to this codebase:

1. **Always run tests and linter**: `rake` before committing
2. **Auto-fix linting issues**: `rake rubocop -A`
3. **Test stdio mode**: `hbt stdio` (logs to `.hbt/logs/PID.log`)
4. **Test HTTP mode**: `hbt start` (logs to stdout)
5. **Test with session**: `HBT_SESSION_ID=test hbt stdio`

## Development Commands

### Essential Commands
- **Run tests**: `rake test` or simply `rake`
- **Run linter**: `rake rubocop`
- **Run tests and linter**: `rake` (default task)
- **Run a single test**: `ruby -Ilib:test test/test_headless_browser_tool.rb -n test_method_name`
- **Build gem**: `bundle exec rake build`
- **Install locally**: `bundle exec rake install`
- **Release to RubyGems**: `bundle exec rake release`

### Development Setup
- **Install dependencies**: `bin/setup` or `bundle install`
- **Open console**: `bin/console` (loads gem in IRB)

## Code Architecture

This is a Ruby gem that provides an MCP (Model Context Protocol) server for browser automation:

### Core Components

- **lib/headless_browser_tool.rb**: Main module entry point
- **lib/headless_browser_tool/server.rb**: HTTP server with SSE support for MCP
- **lib/headless_browser_tool/stdio_server.rb**: Stdio server for direct MCP communication
- **lib/headless_browser_tool/browser.rb**: Browser wrapper around Capybara/Selenium
- **lib/headless_browser_tool/browser_adapter.rb**: Adapter for multi-session browser instances
- **lib/headless_browser_tool/cli.rb**: Command-line interface (Thor-based)

### Session Management

- **lib/headless_browser_tool/session_manager.rb**: Manages multiple browser sessions
- **lib/headless_browser_tool/session_middleware.rb**: Rack middleware for session routing
- **lib/headless_browser_tool/strict_session_middleware.rb**: Enforces X-Session-ID requirement
- **lib/headless_browser_tool/session_persistence.rb**: Handles session save/restore

### Tools System

- **lib/headless_browser_tool/tools/**: 40+ browser automation tools
- **lib/headless_browser_tool/tools/base_tool.rb**: Base class for all tools
- Tools are auto-discovered and registered with the MCP server

### Support Modules

- **lib/headless_browser_tool/logger.rb**: Logging system (stdout for HTTP, file for stdio)
- **lib/headless_browser_tool/directory_setup.rb**: Creates and manages .hbt/ directory structure
- **lib/headless_browser_tool/version.rb**: Gem version constant

### Testing

- **test/**: Minitest test suite
- **examples/**: Example scripts for testing functionality

## Development Guidelines

### General Principles

1. **DRY (Don't Repeat Yourself)**: Extract common functionality into modules
   - Example: `SessionPersistence` module for session save/restore
   - Example: `DirectorySetup` module for directory management

2. **Structured Responses**: All tools should return structured data, not strings
   ```ruby
   # Bad
   "Clicked element: #{selector}"
   
   # Good
   {
     selector: selector,
     element: { tag_name: "button", text: "Submit" },
     navigation: { from: old_url, to: new_url },
     status: "clicked"
   }
   ```

3. **Element Selectors**: When returning arrays of elements, include selectors
   ```ruby
   elements.map.with_index do |element, index|
     {
       selector: "#{base_selector}:nth-of-type(#{index + 1})",
       tag_name: element.tag_name,
       text: element.text
     }
   end
   ```

### Tool Development

1. **Inherit from BaseTool**: All tools must inherit from `HeadlessBrowserTool::Tools::BaseTool`

2. **Use FastMCP DSL**: Define tool metadata using the DSL
   ```ruby
   tool_name "my_tool"
   description "What this tool does"
   
   arguments do
     required(:param).filled(:string).description("Parameter description")
     optional(:flag).filled(:bool).description("Optional flag")
   end
   ```

3. **Implement execute method**: This is where the tool logic goes
   ```ruby
   def execute(param:, flag: false)
     # Tool implementation
     # Return structured data, not strings
   end
   ```

4. **Error Handling**: Let exceptions bubble up - BaseTool handles logging

### Session Management

1. **Multi-session mode**: Default for HTTP server, requires X-Session-ID header
2. **Single-session mode**: For stdio and legacy compatibility
3. **Session persistence**: Use `SessionPersistence` module for save/restore

### Logging

1. **HTTP mode**: Log to stdout using `HeadlessBrowserTool::Logger.log`
2. **Stdio mode**: Log to `.hbt/logs/PID.log` to avoid protocol interference
3. **Always log tool calls**: BaseTool automatically logs all tool executions

### Testing

1. **Run full test suite**: `rake` (runs tests and rubocop)
2. **Fix linting issues**: `rake rubocop -A` for auto-corrections
3. **Test new tools**: Add integration tests when adding new tools

### Code Style

1. **Follow RuboCop rules**: Run `rake rubocop` before committing
2. **Use descriptive names**: Tools should have clear, action-oriented names
3. **Document parameters**: Use the DSL's `.description()` method
4. **Keep methods focused**: Each method should do one thing well

### Common Patterns

1. **Finding elements with fallback**:
   ```ruby
   element = begin
               browser.find_button(text_or_selector)
             rescue Capybara::ElementNotFound
               browser.find(text_or_selector)
             end
   ```

2. **Capturing navigation changes**:
   ```ruby
   url_before = browser.current_url
   # ... perform action ...
   navigated = browser.current_url != url_before
   ```

3. **Safe attribute access**:
   ```ruby
   {
     id: element[:id],
     class: element[:class]
   }.compact  # Remove nil values
   ```

4. **Generating unique selectors for elements**:
   ```ruby
   # For nth element in a collection
   "#{base_selector}:nth-of-type(#{index + 1})"
   
   # Prefer ID selectors when available
   selector = if element[:id] && !element[:id].empty?
                "##{element[:id]}"
              else
                "#{base_selector}:nth-of-type(#{index + 1})"
              end
   ```

5. **Tool result structure**:
   ```ruby
   {
     # Primary data
     selector: selector,
     value: new_value,
     
     # State changes
     was_checked: old_state,
     is_checked: new_state,
     
     # Navigation info (if applicable)
     navigation: {
       navigated: url_changed,
       from: old_url,
       to: new_url
     },
     
     # Always include status
     status: "success"
   }
   ```

### Directory Structure

The gem creates a `.hbt/` directory:
```
.hbt/
├── .gitignore      # Contains "*" to ignore all contents
├── screenshots/    # Screenshot storage
├── sessions/       # Session persistence files (JSON)
└── logs/          # Process logs (stdio mode only)
```

### Adding New Tools

1. Create a new file in `lib/headless_browser_tool/tools/`
2. Follow the naming convention: `action_noun_tool.rb`
3. Register in the ALL_TOOLS constant
4. Return structured data with relevant metadata
5. Include selectors for any returned elements
6. Test with both HTTP and stdio modes

### Debugging Tips

1. **Enable request headers**: `hbt start --show-headers`
2. **Run with visible browser**: `hbt start --no-headless`
3. **Check session files**: Look in `.hbt/sessions/SESSION_ID.json`
4. **Review logs**: Check `.hbt/logs/PID.log` for stdio mode
5. **Test specific tools**: Use `examples/test_*.rb` scripts

### MCP Protocol Considerations

1. **Stdio mode**: Never write to stdout (it's for MCP protocol only)
2. **Response format**: Tools automatically wrap returns in MCP response format
3. **Error handling**: Exceptions become MCP error responses
4. **Tool discovery**: Tools are auto-discovered from the tools/ directory

### Best Practices for Tool Responses

1. **Always return hashes, not strings** - Structured data is easier to parse
2. **Include status field** - Usually "success", "failed", or action-specific
3. **Return before/after state** - For actions that change state
4. **Include selectors** - For elements that might be interacted with later
5. **Keep responses focused** - Only include relevant data
6. **Use consistent field names** - `selector`, `element`, `status`, etc.

### Performance Considerations

1. **Batch operations**: Use `map.with_index` for element collections
2. **Limit text content**: Truncate long text fields (e.g., `.substring(0, 200)`)
3. **Lazy loading**: Only fetch additional data when needed
4. **Session cleanup**: Sessions auto-expire after 30 minutes of inactivity

## Troubleshooting Common Issues

### "No session ID provided" Error
- **Cause**: Multi-session mode requires X-Session-ID header
- **Fix**: Add `-H "X-Session-ID: your-session"` to curl commands
- **Or**: Use `--single-session` flag for shared session mode

### Stdio Logs Not Appearing
- **Location**: Check `.hbt/logs/PID.log` (not stdout)
- **Ensure**: Logger is initialized with `mode: :stdio`
- **Note**: Logger.log must use @instance, not @log

### Session Not Persisting
- **HTTP mode**: Use `--session-id` with `--single-session`
- **Stdio mode**: Set `HBT_SESSION_ID` environment variable
- **Check**: Look for session files in `.hbt/sessions/`

### Tool Not Found
- **Check**: Tool class is in `lib/headless_browser_tool/tools/`
- **Verify**: Tool is added to `ALL_TOOLS` constant
- **Ensure**: Tool class follows naming convention (e.g., `ClickTool`)

### Element Not Found
- **Use**: Tools with wait parameters (e.g., `has_element` with `wait: true`)
- **Try**: More specific selectors (ID > class > tag)
- **Debug**: Use `screenshot` tool to see current page state

## Important Notes

- Ruby >= 3.1.0 is required
- The gem uses Minitest for testing (not RSpec)
- RuboCop is configured for code style enforcement
- Uses Capybara with Selenium WebDriver for browser automation
- Implements MCP (Model Context Protocol) for LLM integration
- Supports both HTTP+SSE and stdio communication modes
- Chrome/Chromium must be installed on the system