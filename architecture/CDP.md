# Chrome DevTools Protocol (CDP) Architecture

## Overview

This document explains the non-obvious aspects of how CDP (Chrome DevTools Protocol) is integrated into the headless-browser-tool to provide undetectable browser automation.

## The Two Execution Contexts

The fundamental concept to understand is that JavaScript can execute in two different contexts:

1. **Main World**: The regular JavaScript context where the webpage's own JavaScript runs
2. **Isolated World**: A separate JavaScript context that can see and manipulate the DOM but is invisible to the page's JavaScript

### Why This Matters

Bot detection scripts check for automation by looking for:
- Modified navigator properties
- Injected JavaScript functions
- Automation-specific variables
- Script execution patterns

When we execute in the **main world** (regular Selenium), our automation is detectable because we share the same JavaScript context as the page.

When we execute in an **isolated world** (CDP), we're invisible to detection scripts while still being able to control the page.

## CDP Implementation Details

### 1. Lazy Initialization

CDP is NOT initialized when the Browser object is created. Instead, it's initialized on the first real navigation (not `about:blank`):

```ruby
def visit(url)
  @session.visit(url)
  
  if @be_human && !@cdp_setup_attempted && url != "about:blank"
    setup_cdp(@session.driver.browser)  # Happens here!
  end
end
```

**Why?** CDP requires an active page context. Initializing too early would fail.

### 2. The Context Problem

When using CDP in isolated world, you cannot:
- Access JavaScript variables set by the page (`window.someVar` returns nil)
- See event listeners attached by the page
- Interact with the page's JavaScript objects

You CAN:
- Read and modify the DOM
- Click elements, fill forms, etc.
- Execute any DOM manipulation
- Navigate the page

### 3. Script Injection Timing

There are two types of script injection:

1. **CDP `addScriptToEvaluateOnNewDocument`**: Runs before page scripts
   - Used when `worldName` is omitted (main world injection)
   - Currently we inject into main world to ensure compatibility

2. **Regular JavaScript injection**: Runs after page loads
   - Used as fallback when CDP fails
   - Also used for `be_mostly_human` mode

### 4. The Return Value Mystery

When executing scripts via CDP in isolated world:
```javascript
// This returns undefined in isolated world:
return window.somePageVariable;

// This works fine:
return document.querySelector('.button').textContent;
```

The DOM is shared between worlds, but JavaScript scope is not.

## Architecture Components

### CDPHuman Module (`cdp_human.rb`)
- Sets up CDP connection
- Manages script injection
- Handles navigation events
- Falls back gracefully on failure

### CDPExecutor (`cdp_executor.rb`)
- Executes JavaScript in specified contexts
- Handles return value serialization
- Manages timeouts and errors
- Key insight: Uses `returnByValue: true` to get actual values, not object references

### CDPContextManager (`cdp_context_manager.rb`)
- Manages execution context lifecycle
- Creates isolated worlds with unique names
- Handles context invalidation on navigation
- **Important**: The rebrowser-patches typo `grantUniveralAccess` (missing 'rs') is intentional compatibility

### CDPElementHelper (`cdp_element_helper.rb`)
- Provides high-level element interaction methods
- Automatically falls back to Selenium when CDP unavailable
- Escapes selectors and strings for safe JavaScript execution

## Mode Behaviors

### Normal Mode (no flags)
- No CDP initialization
- All execution in main world
- Fully detectable automation

### be_mostly_human Mode
- Human-like browser settings (hides automation indicators)
- NO CDP initialization
- Execution stays in main world
- Detectable by sophisticated scripts but passes basic checks

### be_human Mode
- Full CDP initialization
- Execution in isolated world
- Human-like browser settings
- Undetectable by current bot detection methods

## Common Pitfalls

### 1. Chrome Version Compatibility
You'll see warnings like:
```
WARN -- HBT: [CDP] Failed to register navigation handler: wrong constant name Selenium::DevTools::V138::
```
This is because Selenium's DevTools gem is version-specific. The warning is harmless.

### 2. User Agent Modifications
**Don't modify the user agent!** Chrome's natural user agent is correct. Modifying it actually makes detection easier, not harder.

### 3. Context Confusion
Remember which context you're in:
```ruby
# In isolated world (CDP), this is nil:
browser.execute_script("return window.jQuery")

# But this works:
browser.execute_script("return document.body.innerHTML")
```

### 4. Timing Issues
CDP setup happens asynchronously. There's a small delay between navigation and CDP being ready. The code handles this, but be aware when debugging.

## Debugging CDP

Enable debug logging:
```bash
export HBT_CDP_DEBUG=true
```

Check if CDP is active:
```ruby
browser.cdp_available?  # true if CDP is initialized and working
```

Force execution via Selenium (bypass CDP):
```ruby
browser.instance_variable_set(:@cdp_initialized, false)
browser.execute_script("...")  # Now uses Selenium
browser.instance_variable_set(:@cdp_initialized, true)
```

## Why Not Always Use CDP?

1. **Compatibility**: Some operations are complex in CDP (like drag-and-drop)
2. **Performance**: CDP has slight overhead for simple operations
3. **Debugging**: Main world execution is easier to debug
4. **Flexibility**: Users may want human-like settings without the CDP complexity

## Future Considerations

1. **Chrome Updates**: The DevTools protocol evolves. Version-specific code may need updates.
2. **Detection Evolution**: As bot detection improves, we may need to enhance our isolated world implementation.
3. **Performance**: Consider connection pooling for CDP if many operations are needed.

## Key Takeaway

The magic of CDP is **context isolation**. We can control the browser without leaving traces in the JavaScript environment that bot detectors examine. It's not about being "stealthy" - it's about operating in a space the page cannot observe.