1. **Standardize tool return values**: All tools should return a consistent structure with a standard status field.
2. **Document tool contracts**: Each tool should clearly document what it returns so tests can have correct expectations.
3. **Consider making Browser methods match BrowserAdapter**: The Browser class should have the same public interface as BrowserAdapter to avoid confusion.
4. **Add integration tests for new methods**: When adding methods like `text` or `windows`, ensure they're tested properly.
5. **Fix Tool Return Values**: Many tools are returning inconsistent status fields
6. **Handle Nil Returns**: Add defensive coding for tool responses
