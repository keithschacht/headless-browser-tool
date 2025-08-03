  1. CDP-Specific Tests
    - CDP initialization on first navigation (lazy loading)
    - CDP fallback when setup fails
    - All cdp_element_action methods (click, hover, etc. with CDP)
    - CDP execution context (isolated world vs main world)
    - CDP navigation handler with different Chrome versions
  2. Human Mode Tests (complex)
    - inject_human_js verification (all browser properties masked)
    - Chrome options verification in human mode
    - User agent behavior testing
    - Bot detection test integration
  3. Complex Tool Tests
    - drag operations
    - file upload (attach_file)
    - execute_script and evaluate_script with complex JS
    - screenshot with annotations and highlights
    - visual_diff functionality
    - auto_narrate and narration history
  4. Session Persistence Tests
    - Save/restore session state
    - Session timeout (30 minutes)
    - Session cleanup for dead sessions
    - Browser crash recovery
  5. Integration Tests
    - Full MCP protocol flow
    - Real website testing (not just bot-detector)
    - Frame/iframe handling
    - Popup/alert handling
    - JavaScript error handling
  6. Concurrent Session Tests
    - Multiple sessions running simultaneously
    - Session isolation
    - Resource management
  7. Edge Cases and Error Handling
    - Invalid selectors
    - Timing issues with dynamic elements
    - Memory leak testing
    - Performance benchmarks
