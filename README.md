# Headless Browser Tool

A headless browser control tool that provides an MCP (Model Context Protocol) server with tools to control a headless browser using Capybara and Selenium. Features multi-session support, session persistence, and both HTTP and stdio communication modes.

## Quick Start to use this as an MCP server (E.g. with Claude Code)

```bash
# First, if you don't have a new version of Ruby (Mac's don't have this pre-installed) then:
brew install ruby
# Don't forget to add Ruby to your shell's path and restart your shell:
# For bash:
# echo 'export PATH="/opt/homebrew/opt/ruby/bin:$PATH"' >> ~/.bash_profile && source ~/.bash_profile

```

```bash
gem install https://github.com/krschacht/headless-browser-tool
claude mcp add headless-browser hbt stdio --
claude
```

If you want to watch the browser work, add the `--no-headless` flag like `hbt stdio -- --no-headless`. If any websites are blocking you because of automation, also add the `--be-human` flag. If you want to persist the browser between Claude sessions, run it in HTTP mode instead:

```bash
gem install https://github.com/krschacht/headless-browser-tool
hbt start  # Starts an http server, supports the same flags but don't use "--" seperator.
           # You can run it in the background by registering with Launch Agent
           # or simply: nohup hbt start > ~/.hbt/server.log 2>&1 &
claude mcp add --transport http headless-browser http://localhost:4567/mcp
claude
```

## Features

- **Headless Chrome browser automation** - Full browser control via Selenium WebDriver
- **MCP server with 40+ browser control tools** - Comprehensive API for browser interactions
- **Multi-session support** - Isolated browser sessions for each client
- **Session persistence** - Sessions survive server restarts with cookies and state preservation
- **Two server modes** - HTTP server mode and stdio mode for different integration patterns
- **Smart screenshot tools** - With annotations, highlighting, and visual diff capabilities
- **AI-assisted tools** - Intelligent page analysis and context extraction
- **Comprehensive logging** - Separate log files for stdio mode to avoid protocol interference
- **Structured responses** - All tools return rich, structured data instead of simple strings
- **Smart element selectors** - Tools returning multiple elements include selectors for each

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'headless_browser_tool'
```

And then execute:

```bash
bundle install
```

Or install it yourself as:

```bash
gem install headless_browser_tool
```

## Prerequisites

You need to have Chrome/Chromium browser installed on your system. The gem will use Chrome in headless mode by default.

## Usage

### Command Line Interface

The `hbt` command provides three main commands:

#### `hbt start` - Start HTTP Server Mode

Starts the MCP server as an HTTP server with SSE (Server-Sent Events) support:

```bash
hbt start [OPTIONS]
```

**Options:**
- `--port PORT` - Port for the MCP server (default: 4567)
- `--headless` / `--no-headless` - Run browser in headless mode (default: true)
- `--single-session` - Use single shared browser session instead of multi-session mode
- `--session-id SESSION_ID` - Enable session persistence for single session mode (requires `--single-session`)
- `--show-headers` - Show HTTP request headers for debugging session issues
- `--be-human` - Be human-like in browser interactions.
- `--be-mostly-human` - Be human-like in browser interactions except continue to execute in the main world context since this optimization may be brittle in some cases.

**Examples:**
```bash
# Start with default settings (multi-session, headless, port 4567)
hbt start

# Start in non-headless mode for debugging
hbt start --no-headless

# Start in single session mode (legacy compatibility)
hbt start --single-session

# Start in single session mode with persistence
hbt start --single-session --session-id my-app-session

# Start with request header logging
hbt start --show-headers
```

#### `hbt stdio` - Start Stdio Server Mode

Starts the MCP server in stdio mode for direct integration with tools that spawn subprocesses:

```bash
hbt stdio [OPTIONS]
```

**Options:**
- `--headless` / `--no-headless` - Run browser in headless mode (default: true)

**Notes:**
- Always runs in single-session mode
- Logs to `.hbt/logs/PID.log` instead of stdout to avoid interfering with MCP protocol
- Ideal for editor integrations and tools that communicate via stdin/stdout
- Supports optional session persistence via `HBT_SESSION_ID` environment variable

**Session Persistence in Stdio Mode:**

You can enable session persistence by setting the `HBT_SESSION_ID` environment variable:

```bash
# First run - creates and saves session
HBT_SESSION_ID=my-editor-session hbt stdio

# Later run - restores previous session state
HBT_SESSION_ID=my-editor-session hbt stdio
```

When `HBT_SESSION_ID` is set:
- Session state is saved to `.hbt/sessions/{session_id}.json` on exit
- On startup, if the session file exists, it restores:
  - Current URL
  - Cookies
  - localStorage
  - sessionStorage
  - Window size

This is useful for editor integrations that want to maintain browser state across multiple tool invocations.

**Examples:**
```bash
# Start in stdio mode (headless by default, no persistence)
hbt stdio

# Start with session persistence
HBT_SESSION_ID=vscode-session hbt stdio

# Start in stdio mode with visible browser
hbt stdio --no-headless
```

#### `hbt version` - Display Version

Shows the current version of HeadlessBrowserTool:

```bash
hbt version
```

### Session Management

#### Multi-Session Mode (Default for HTTP Server)

In multi-session mode, each client connection gets its own isolated browser session with:
- **Separate cookies and localStorage** - Complete isolation between sessions
- **Independent navigation history** - Each session maintains its own browser state
- **Session persistence** - Sessions are saved to `.hbt/sessions/` and restored on restart
- **Automatic cleanup** - Idle sessions are closed after 30 minutes
- **LRU eviction** - When at capacity (10 sessions), least recently used sessions are closed

**Session Identification in Multi-Session Mode:**

For HTTP server mode, sessions require an `X-Session-ID` header:

```bash
# Connect with session ID "alice"
curl -H "X-Session-ID: alice" -H "Accept: text/event-stream" http://localhost:4567/

# Different session ID gets different browser
curl -H "X-Session-ID: bob" -H "Accept: text/event-stream" http://localhost:4567/

# Without X-Session-ID header, connection is rejected
curl -H "Accept: text/event-stream" http://localhost:4567/
# Returns: 400 Bad Request - X-Session-ID header is required
```

**Session ID Requirements:**
- Must be provided via `X-Session-ID` header
- Can only contain alphanumeric characters, underscores, and hyphens
- Maximum length: 64 characters
- Invalid formats are rejected with 400 error

#### Single Session Mode

Use `--single-session` flag for legacy mode where all clients share one browser:
```bash
hbt start --single-session
```

**Session Persistence in Single Session Mode:**

You can enable session persistence with the `--session-id` flag:

```bash
# First run - creates and saves session
hbt start --single-session --session-id my-app

# Server restart - restores previous session
hbt start --single-session --session-id my-app
```

When `--session-id` is provided:
- Session state is saved to `.hbt/sessions/{session_id}.json` on shutdown
- On startup, if the session file exists, it restores browser state
- All clients share this single persistent session
- Compatible with stdio mode session files

This is useful for:
- Development servers that need to maintain login state
- Testing environments where you want consistent browser state
- Applications that don't need multi-user isolation

**Note:** The `--session-id` flag can only be used with `--single-session`. In multi-session mode, session IDs are provided by clients via headers.

#### Session Management Endpoints

**View active sessions:**
```bash
curl http://localhost:4567/sessions | jq
```

Response:
```json
{
  "active_sessions": ["alice", "bob"],
  "session_count": 2,
  "session_data": {
    "alice": {
      "created_at": "2024-01-20T10:00:00Z",
      "last_activity": "2024-01-20T10:05:00Z",
      "idle_time": 300.5
    }
  }
}
```

**Close a specific session:**
```bash
curl -X DELETE http://localhost:4567/sessions/alice
```

### Directory Structure

HeadlessBrowserTool creates a `.hbt/` directory with:
```
.hbt/
├── .gitignore      # Contains "*" to ignore all contents
├── screenshots/    # Screenshot storage
├── sessions/       # Session persistence files
└── logs/          # Log files (stdio mode only)
    └── PID.log    # Process-specific log file
```

### MCP API

The server implements the Model Context Protocol (MCP) and responds to JSON-RPC requests.

#### Using with MCP Clients

For HTTP mode with proper MCP clients:
```bash
# Start server
hbt start

# MCP client should:
# 1. Connect with X-Session-ID header
# 2. Use SSE endpoint for streaming: http://localhost:4567/mcp/sse
# 3. Send commands via JSON-RPC
```

For stdio mode:
```bash
# MCP client spawns the process directly
hbt stdio
# Communication happens via stdin/stdout
```

### Available Browser Tools

All tools are available through the MCP protocol. Here's a complete reference:

#### Navigation Tools

| Tool | Description | Parameters | Returns |
|------|-------------|------------|----------|
| `visit` | Navigate to a URL | `url` (required) | `{url, current_url, title, status}` |
| `refresh` | Reload the current page | None | `{url, title, changed, status}` |
| `go_back` | Navigate back in browser history | None | `{navigation: {from, to, title, navigated}, status}` |
| `go_forward` | Navigate forward in browser history | None | `{navigation: {from, to, title, navigated}, status}` |

#### Element Interaction Tools

| Tool | Description | Parameters | Returns |
|------|-------------|------------|----------|
| `click` | Click an element | `selector` (required) | `{selector, element, navigation, status}` |
| `right_click` | Right-click an element | `selector` (required) | `{selector, element, status}` |
| `double_click` | Double-click an element | `selector` (required) | `{selector, element, status}` |
| `hover` | Hover mouse over element | `selector` (required) | `{selector, element, status}` |
| `drag` | Drag element to target | `source_selector`, `target_selector` (required) | `{source_selector, target_selector, source, target, status}` |

#### Element Finding Tools

| Tool | Description | Parameters | Key Returns |
|------|-------------|------------|-------------|
| `find_element` | Find single element | `selector` (required) | Element details with attributes |
| `find_all` | Find all matching elements | `selector` (required) | `{elements: [{selector, tag_name, text, visible, attributes}]}` |
| `find_elements_containing_text` | Find elements with text | `text` (required), `case_sensitive`, `visible_only` | `{elements: [{selector, xpath, tag, text, clickable}]}` |
| `get_text` | Get element text | `selector` (required) | Text content string |
| `get_page_as_markdown` | Convert page/element to markdown | `selector` (optional) | Markdown string |
| `get_attribute` | Get element attribute | `selector`, `attribute` (required) | Attribute value |
| `get_value` | Get input value | `selector` (required) | Input value |
| `is_visible` | Check element visibility | `selector` (required) | Boolean |
| `has_element` | Check element exists | `selector` (required), `wait` | Boolean |
| `has_text` | Check text exists | `text` (required), `wait` | Boolean |

#### Form Interaction Tools

| Tool | Description | Parameters | Key Returns |
|------|-------------|------------|-------------|
| `fill_in` | Fill input field | `field`, `value` (required) | `{field, value, field_info, status}` |
| `select` | Select dropdown option | `value`, `dropdown_selector` (required) | `{selected_value, selected_text, options: [{selector, value, text}]}` |
| `check` | Check checkbox | `checkbox_selector` (required) | `{selector, was_checked, is_checked, element, status}` |
| `uncheck` | Uncheck checkbox | `checkbox_selector` (required) | `{selector, was_checked, is_checked, element, status}` |
| `choose` | Select radio button | `radio_button_selector` (required) | `{selector, radio, group: [{selector, value, checked}], status}` |
| `attach_file` | Upload file | `file_field_selector`, `file_path` (required) | `{field_selector, file_path, file_name, file_size, field, status}` |
| `click_button` | Click button | `button_text_or_selector` (required) | `{button, element, navigation, status}` |
| `click_link` | Click link | `link_text_or_selector` (required) | `{link, element, navigation, status}` |

#### Page Information Tools

| Tool | Description | Returns |
|------|-------------|---------|
| `get_current_url` | Get current URL | Full URL string |
| `get_current_path` | Get current path | Path without domain |
| `get_page_title` | Get page title | Title string |
| `get_page_source` | Get HTML source | Full HTML |
| `get_page_context` | Analyze page structure and available actions | Navigation, forms, buttons, and page layout metadata |

#### Search Tools

| Tool | Description | Parameters |
|------|-------------|------------|
| `search_page` | Search visible content | `query` (required), `case_sensitive`, `regex`, `context_lines`, `highlight` |
| `search_source` | Search HTML source | `query` (required), `case_sensitive`, `regex`, `context_lines`, `show_line_numbers` |

#### JavaScript Execution Tools

| Tool | Description | Parameters | Returns |
|------|-------------|------------|----------|
| `execute_script` | Run JavaScript | `javascript_code` (required) | `{javascript_code, execution_time, timestamp, status}` |
| `evaluate_script` | Run JS and return result | `javascript_code` (required) | Script return value |

#### Screenshot and Capture Tools

| Tool | Description | Parameters | Key Returns |
|------|-------------|------------|-------------|
| `screenshot` | Take screenshot | `filename`, `highlight_selectors`, `annotate`, `full_page` | `{file_path, filename, file_size, timestamp, url, title}` |
| `save_page` | Save HTML to file | `file_path` (required) | `{file_path, file_size, timestamp, url, title, status}` |
| `visual_diff` | Summarize what changed on the page since last call to this tool | |

#### Window Management Tools

| Tool | Description | Parameters | Key Returns |
|------|-------------|------------|-------------|
| `switch_to_window` | Switch to window/tab | `window_handle` (required) | `{window_handle, previous_window, current_url, title, total_windows}` |
| `open_new_window` | Open new window/tab | None | `{window_handle, total_windows, previous_windows, current_window}` |
| `close_window` | Close window/tab | `window_handle` (required) | `{closed_window, was_current, remaining_windows, current_window}` |
| `get_window_handles` | Get all window handles | None | `{current_window, windows: [{handle, index, is_current}], total_windows}` |
| `maximize_window` | Maximize window | None | `{size_before: {width, height}, size_after: {width, height}, status}` |
| `resize_window` | Resize window | `width`, `height` (required) | `{requested_size, size_before, size_after, status}` |

#### Session Management Tools

| Tool | Description | Returns |
|------|-------------|---------|
| `get_session_info` | Get session information | Session details |

### Tool Response Structure

All tools now return structured data instead of simple strings. This makes it easier to:
- Extract specific information from responses
- Check operation success/failure
- Access element properties and metadata
- Navigate to specific elements using returned selectors

**Example responses:**

```json
// visit tool response
{
  "url": "https://example.com",
  "current_url": "https://example.com/",
  "title": "Example Domain",
  "status": "success"
}

// find_all tool response with selectors
{
  "selector": ".item",
  "count": 3,
  "elements": [
    {
      "index": 0,
      "selector": ".item:nth-of-type(1)",
      "tag_name": "div",
      "text": "Item 1",
      "visible": true,
      "attributes": {"class": "item active"}
    },
    // ... more elements
  ]
}

// select tool response with option selectors
{
  "dropdown_selector": "#country",
  "selected_value": "US",
  "selected_text": "United States",
  "options": [
    {
      "selector": "#country option:nth-of-type(1)",
      "value": "US",
      "text": "United States",
      "selected": true
    },
    // ... more options
  ],
  "status": "selected"
}
```

### Example Tool Calls

Here are examples using curl with the HTTP server:

```bash
# Navigate to a URL
curl -X POST http://localhost:4567/ \
  -H "Content-Type: application/json" \
  -H "X-Session-ID: alice" \
  -d '{"jsonrpc": "2.0", "id": 1, "method": "tools/call",
       "params": {"name": "visit", "arguments": {"url": "https://example.com"}}}'

# Take an annotated screenshot
curl -X POST http://localhost:4567/ \
  -H "Content-Type: application/json" \
  -H "X-Session-ID: alice" \
  -d '{"jsonrpc": "2.0", "id": 2, "method": "tools/call",
       "params": {"name": "screenshot",
                  "arguments": {"filename": "example",
                              "highlight_selectors": [".error", ".warning"],
                              "annotate": true,
                              "full_page": true}}}'

# Search page content with highlighting
curl -X POST http://localhost:4567/ \
  -H "Content-Type: application/json" \
  -H "X-Session-ID: alice" \
  -d '{"jsonrpc": "2.0", "id": 3, "method": "tools/call",
       "params": {"name": "search_page",
                  "arguments": {"query": "error|warning",
                              "regex": true,
                              "highlight": true}}}'
```

### Environment Variables

- `HBT_SINGLE_SESSION=true` - Force single session mode in HTTP server
- `HBT_SHOW_HEADERS=true` - Enable request header logging in HTTP server
- `HBT_SESSION_ID=<session_name>` - Enable session persistence in stdio mode

### Logging

- **HTTP mode**: Logs to stdout
- **Stdio mode**: Logs to `.hbt/logs/PID.log` to avoid interfering with MCP protocol

Tool calls are logged with format:
```
INFO -- HBT: CALL: ToolName [] {args} -> result
ERROR -- HBT: ERROR: ToolName [] {args} -> error_message
```

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake test` to run the tests. You can also run `bin/console` for an interactive prompt.

To install this gem onto your local machine, run `bundle exec rake install`.

### Running Tests and Linting

```bash
# Run tests
rake test

# Run linter
rake rubocop

# Run linter with auto-fix
rake rubocop -A

# Run both tests and linter (default task)
rake
```

## Recent Improvements

### Version 0.1.0

- **Structured tool responses** - All tools now return rich JSON objects instead of simple strings
- **Element selectors in arrays** - Tools returning multiple elements include unique selectors for each
- **Session persistence** - Both stdio and single-session HTTP modes support persistent sessions
- **Strict session management** - Multi-session mode requires X-Session-ID header (no auto-creation)
- **Improved logging** - Fixed stdio mode logging to properly write to `.hbt/logs/PID.log`
- **DRY refactoring** - Extracted common functionality into `SessionPersistence` and `DirectorySetup` modules
- **Better error handling** - Tools return structured error information
- **Enhanced tool responses**:
  - Navigation tools return before/after URLs and navigation status
  - Form tools return element state before/after interaction
  - Window tools return comprehensive window state information
  - Screenshot tool returns file metadata
  - All element-finding tools return complete element information

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/parruda/headless_browser_tool.
Tip for developers who want to test this locally. It's helpful to create an hbt-dev script, e.g.:

I saved this as `hbt-dev` in my `~/bin/hbt-dev`

```bash
#!/bin/bash
exec ruby -I/PATH-TO-REPO/headless-browser-tool/lib /PATH-TO-REPO/headless-browser-tool/exe/hbt "$@"
```

Then you can change Claude's registered MCP to use this:

```bash
claude mcp remove headless-browser
claude mcp add headless-browser ~/bin/hbt-dev stdio --
```
