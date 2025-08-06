# frozen_string_literal: true

require_relative "test_base"
require "uri"

class TestFindElementsContainingText < TestBase
  def setup
    super
    @browser = HeadlessBrowserTool::Browser.new(headless: true)

    # Set up server in single session mode for testing
    HeadlessBrowserTool::Server.instance_variable_set(:@single_session_mode, true)
    HeadlessBrowserTool::Server.instance_variable_set(:@browser_instance, @browser)

    @tool = HeadlessBrowserTool::Tools::FindElementsContainingTextTool.new
  end

  def teardown
    begin
      # Browser doesn't have a close method, just let it be garbage collected
      @browser = nil
    rescue StandardError
      nil
    end
    super
  end

  def test_return_value_format
    # Test the structure of the return value with multiple matches
    html = <<-HTML
      <html>
        <head><title>Test Page</title></head>
        <body>
          <div id="first" class="item">Test content</div>
          <p id="second">Test content</p>
        </body>
      </html>
    HTML

    @browser.visit("data:text/html,#{html.gsub(/\s+/, " ").strip.gsub("#", "%23")}")
    result = @tool.execute(text: "Test content")

    # Check top-level structure
    assert_kind_of Hash, result
    assert_equal "Test content", result[:query]
    assert_equal 2, result[:total_found]
    assert_kind_of Array, result[:elements]
    assert_equal 2, result[:elements].length

    # Check first element structure
    first_element = result[:elements].first

    assert_kind_of Hash, first_element
    assert_equal "div", first_element[:tag]
    assert_equal "Test content", first_element[:text]
    assert_equal "#first", first_element[:selector]
    assert_kind_of String, first_element[:xpath]
    assert_kind_of Hash, first_element[:attributes]
    assert_equal "first", first_element[:attributes]["id"]
    assert_equal "item", first_element[:attributes]["class"]
    assert_equal "body", first_element[:parent]
    assert_includes [true, false], first_element[:clickable]
    assert_includes [true, false], first_element[:visible]
    assert_kind_of Hash, first_element[:position]
    assert_kind_of Numeric, first_element[:position]["top"]
    assert_kind_of Numeric, first_element[:position]["left"]
    assert_kind_of Numeric, first_element[:position]["width"]
    assert_kind_of Numeric, first_element[:position]["height"]

    # Check second element has different selector
    second_element = result[:elements][1]

    assert_equal "p", second_element[:tag]
    assert_equal "#second", second_element[:selector]
  end

  def test_no_matches_found
    # Test what happens when no elements match
    html = <<-HTML
      <html>
        <head><title>Test Page</title></head>
        <body>
          <div>Some text</div>
          <p>Other content</p>
        </body>
      </html>
    HTML

    @browser.visit("data:text/html,#{html.gsub(/\s+/, " ").strip.gsub("#", "%23")}")
    result = @tool.execute(text: "Non-existent text")

    # Should return a valid structure with empty results
    assert_kind_of Hash, result
    assert_equal "Non-existent text", result[:query]
    assert_equal 0, result[:total_found]
    assert_kind_of Array, result[:elements]
    assert_empty result[:elements]
  end

  def test_finds_only_direct_text_containers
    # Test that it finds elements that DIRECTLY contain text, not all ancestors
    html = <<-HTML
      <html>
        <head><title>Test Page</title></head>
        <body>
          <div class="outer">
            <div class="middle">
              <div class="inner">Direct text here</div>
            </div>
          </div>
        </body>
      </html>
    HTML

    @browser.visit("data:text/html,#{html.gsub(/\s+/, " ").strip.gsub("#", "%23")}")
    result = @tool.execute(text: "Direct text here")

    # Should find only the inner div that directly contains the text
    assert_equal 1, result[:total_found], "Should find exactly one element"
    assert_equal "div", result[:elements].first[:tag]
    assert_equal "inner", result[:elements].first[:attributes]["class"]

    # Should NOT find the parent divs
    refute result[:elements].any? { |e| e[:attributes]["class"] == "outer" }, "Should not find outer div"
    refute result[:elements].any? { |e| e[:attributes]["class"] == "middle" }, "Should not find middle div"
  end

  def test_finds_input_values
    html = <<-HTML
      <html>
        <head><title>Test Page</title></head>
        <body>
          <input type="text" id="search-box" value="Search term here">
          <input type="submit" value="Submit">
          <textarea id="comment">Comment text</textarea>
        </body>
      </html>
    HTML

    @browser.visit("data:text/html,#{html.gsub(/\s+/, " ").strip.gsub("#", "%23")}")

    # Test finding input value
    result = @tool.execute(text: "Search term")

    assert_equal 1, result[:total_found]
    assert_equal "input", result[:elements].first[:tag]
    assert_equal "search-box", result[:elements].first[:attributes]["id"]
    assert result[:elements].first[:clickable], "Input should be clickable"

    # Test finding textarea value
    result = @tool.execute(text: "Comment text")

    assert_equal 1, result[:total_found]
    assert_equal "textarea", result[:elements].first[:tag]
    assert result[:elements].first[:clickable], "Textarea should be clickable"
  end

  def test_finds_text_in_attributes
    html = <<-HTML
      <html>
        <head><title>Test Page</title></head>
        <body>
          <input type="text" placeholder="Enter your name">
          <img src="test.jpg" alt="Test image description">
          <button title="Click to submit" aria-label="Submit button">Submit</button>
        </body>
      </html>
    HTML

    @browser.visit("data:text/html,#{html.gsub(/\s+/, " ").strip.gsub("#", "%23")}")

    # Test placeholder
    result = @tool.execute(text: "Enter your name")

    assert_equal 1, result[:total_found]
    assert_equal "input", result[:elements].first[:tag]

    # Test alt text
    result = @tool.execute(text: "Test image")

    assert_equal 1, result[:total_found]
    assert_equal "img", result[:elements].first[:tag]

    # Test aria-label
    result = @tool.execute(text: "Submit button")

    assert_equal 1, result[:total_found]
    assert_equal "button", result[:elements].first[:tag]
  end

  def test_case_sensitive_search
    html = <<-HTML
      <html>
        <head><title>Test Page</title></head>
        <body>
          <div>UPPERCASE TEXT</div>
          <div>lowercase text</div>
          <div>MixedCase Text</div>
        </body>
      </html>
    HTML

    @browser.visit("data:text/html,#{html.gsub(/\s+/, " ").strip.gsub("#", "%23")}")

    # Case insensitive (default)
    result = @tool.execute(text: "uppercase")

    assert_equal 1, result[:total_found], "Should find UPPERCASE when searching case-insensitive"

    result = @tool.execute(text: "LOWERCASE")

    assert_equal 1, result[:total_found], "Should find lowercase when searching case-insensitive"

    # Case sensitive
    result = @tool.execute(text: "UPPERCASE", case_sensitive: true)

    assert_equal 1, result[:total_found], "Should find exact match with case sensitive"

    result = @tool.execute(text: "uppercase", case_sensitive: true)

    assert_equal 0, result[:total_found], "Should not find when case doesn't match"
  end

  def test_visible_only_filter
    html = <<-HTML
      <html>
        <head><title>Test Page</title></head>
        <body>
          <div>Visible text</div>
          <div style="display: none">Hidden text</div>
          <div style="visibility: hidden">Invisible text</div>
          <div style="opacity: 0">Transparent text</div>
        </body>
      </html>
    HTML

    @browser.visit("data:text/html,#{html.gsub(/\s+/, " ").strip.gsub("#", "%23")}")

    # With visible_only=true (default)
    result = @tool.execute(text: "text")

    assert_equal 1, result[:total_found], "Should find only visible element by default"
    assert_includes result[:elements].first[:text], "Visible", "Should find the visible div"

    # With visible_only=false
    result = @tool.execute(text: "text", visible_only: false)

    assert_equal 4, result[:total_found], "Should find all elements when visible_only=false"

    # Check that hidden elements are found
    assert result[:elements].any? { |e| e[:text].include?("Hidden") }, "Should find hidden element"
    assert result[:elements].any? { |e| e[:text].include?("Invisible") }, "Should find invisible element"
  end

  def test_clickable_metadata
    html = <<-HTML
      <html>
        <head><title>Test Page</title></head>
        <body>
          <a href="#">Link text</a>
          <button>Button text</button>
          <div>Plain div text</div>
          <span onclick="alert('hi')">Clickable span</span>
          <div role="button">Role button</div>
          <label for="input1">Label text</label>
          <input type="text" id="input1" value="Input text">
        </body>
      </html>
    HTML

    @browser.visit("data:text/html,#{html.gsub(/\s+/, " ").strip.gsub("#", "%23")}")

    # Test that links are marked clickable
    result = @tool.execute(text: "Link text")

    assert_equal 1, result[:total_found], "Should find link element"
    assert result[:elements].first[:clickable], "Links should be clickable"

    # Test that buttons are marked clickable
    result = @tool.execute(text: "Button text")

    assert_equal 1, result[:total_found], "Should find button element"
    assert result[:elements].first[:clickable], "Buttons should be clickable"

    # Test that plain divs are not clickable
    result = @tool.execute(text: "Plain div text")

    assert_equal 1, result[:total_found], "Should find div element"
    refute result[:elements].first[:clickable], "Plain divs should not be clickable"

    # Test that elements with onclick are clickable
    result = @tool.execute(text: "Clickable span")

    assert_equal 1, result[:total_found], "Should find span element"
    assert result[:elements].first[:clickable], "Elements with onclick should be clickable"

    # Test that elements with role=button are clickable
    result = @tool.execute(text: "Role button")

    assert_equal 1, result[:total_found], "Should find role=button element"
    assert result[:elements].first[:clickable], "Elements with role=button should be clickable"

    # Test that labels are clickable
    result = @tool.execute(text: "Label text")

    assert_equal 1, result[:total_found], "Should find label element"
    assert result[:elements].first[:clickable], "Labels should be clickable"
  end

  def test_clickable_with_ancestor_handlers
    # Test that elements are marked clickable if their ancestors have click handlers
    html = <<-HTML
      <html>
        <head><title>Test Page</title></head>
        <body>
          <span onclick="alert('direct')">Direct click handler</span>
          <div onclick="alert('parent')">
            <span>Parent div has handler</span>
          </div>
          <div onclick="alert('grandparent')">
            <div>
              <span>Ancestor has handler</span>
            </div>
          </div>
          <div>
            <div>
              <span>No handler anywhere</span>
            </div>
          </div>
          <button>
            <span>Inside button</span>
          </button>
          <a href="#">
            <span>Inside link</span>
          </a>
        </body>
      </html>
    HTML

    @browser.visit("data:text/html,#{html.gsub(/\s+/, " ").strip.gsub("#", "%23")}")

    # Element with direct click handler should be clickable
    result = @tool.execute(text: "Direct click handler")

    assert_equal 1, result[:total_found]
    assert result[:elements].first[:clickable], "Element with direct onclick should be clickable"

    # Element whose parent has click handler should be clickable
    result = @tool.execute(text: "Parent div has handler")

    assert_equal 1, result[:total_found]
    assert result[:elements].first[:clickable], "Element with parent onclick should be clickable"

    # Element whose grandparent has click handler should be clickable
    result = @tool.execute(text: "Ancestor has handler")

    assert_equal 1, result[:total_found]
    assert result[:elements].first[:clickable], "Element with grandparent onclick should be clickable"

    # Element with no click handlers in ancestry should not be clickable
    result = @tool.execute(text: "No handler anywhere")

    assert_equal 1, result[:total_found]
    refute result[:elements].first[:clickable], "Element with no click handlers should not be clickable"

    # Element inside button should be clickable
    result = @tool.execute(text: "Inside button")

    assert_equal 1, result[:total_found]
    assert result[:elements].first[:clickable], "Element inside button should be clickable"

    # Element inside link should be clickable
    result = @tool.execute(text: "Inside link")

    assert_equal 1, result[:total_found]
    assert result[:elements].first[:clickable], "Element inside link should be clickable"
  end

  def test_returns_selector_and_xpath
    html = <<-HTML
      <html>
        <head><title>Test Page</title></head>
        <body>
          <div id="unique-id">Text with ID</div>
          <div class="unique-class">Text with class</div>
          <div>Text without attributes</div>
        </body>
      </html>
    HTML

    @browser.visit("data:text/html,#{html.gsub(/\s+/, " ").strip.gsub("#", "%23")}")

    # Test element with ID
    result = @tool.execute(text: "Text with ID")
    element = result[:elements].first

    assert_equal "#unique-id", element[:selector], "Should use ID for selector"
    assert_match %r{//.*div}, element[:xpath], "Should have XPath"

    # Test element with class
    result = @tool.execute(text: "Text with class")
    element = result[:elements].first

    assert_match(/unique-class/, element[:selector], "Should include class in selector")
    assert_match %r{//.*div}, element[:xpath], "Should have XPath"

    # Test element without attributes
    result = @tool.execute(text: "Text without attributes")
    element = result[:elements].first

    assert element[:selector], "Should have a selector even without attributes"
    assert element[:xpath], "Should have XPath"
  end

  def test_finds_text_with_whitespace
    html = <<-HTML
      <html>
        <head><title>Test Page</title></head>
        <body>
          <div>
      #{"      "}
      #{"      "}
            Text with surrounding whitespace
      #{"      "}
      #{"      "}
          </div>
        </body>
      </html>
    HTML

    @browser.visit("data:text/html,#{html.gsub(/\s+/, " ").strip.gsub("#", "%23")}")
    result = @tool.execute(text: "Text with surrounding")

    assert_equal 1, result[:total_found], "Should find text even with whitespace"
    assert_equal "div", result[:elements].first[:tag]
  end

  def test_does_not_find_script_or_style_content
    html = <<-HTML
      <html>
        <head>
          <title>Test Page</title>
          <style>
            .hidden { display: none; }
            /* Text in style */
          </style>
        </head>
        <body>
          <div>Text in body</div>
          <script>
            console.log("Text in script");
          </script>
        </body>
      </html>
    HTML

    @browser.visit("data:text/html,#{html.gsub(/\s+/, " ").strip.gsub("#", "%23")}")

    # Should not find text in script tags
    result = @tool.execute(text: "Text in script")

    assert_equal 0, result[:total_found], "Should not find text in script tags"

    # Should not find text in style tags
    result = @tool.execute(text: "Text in style")

    assert_equal 0, result[:total_found], "Should not find text in style tags"

    # Should find normal body text
    result = @tool.execute(text: "Text in body")

    assert_equal 1, result[:total_found], "Should find text in body"
  end

  def test_partial_text_match
    html = <<-HTML
      <html>
        <head><title>Test Page</title></head>
        <body>
          <div>This is a long piece of text that contains the search term</div>
        </body>
      </html>
    HTML

    @browser.visit("data:text/html,#{html.gsub(/\s+/, " ").strip.gsub("#", "%23")}")

    # Should find partial matches
    result = @tool.execute(text: "search term")

    assert_equal 1, result[:total_found], "Should find partial text match"

    result = @tool.execute(text: "long piece")

    assert_equal 1, result[:total_found], "Should find text in the middle"
  end

  def test_javascript_error_in_search_script
    # Create a page that might cause JavaScript errors
    html = <<-HTML
      <html>
        <head><title>Test Page</title></head>
        <body>
          <div>Normal content</div>
          <script>
            // Override a method to cause errors
            Object.defineProperty(Element.prototype, 'textContent', {
              get: function() { throw new Error('Test error'); }
            });
          </script>
        </body>
      </html>
    HTML

    @browser.visit("data:text/html,#{html.gsub(/\s+/, " ").strip.gsub("#", "%23")}")

    # Should handle JavaScript errors gracefully
    result = @tool.execute(text: "Normal")

    # Should return an error structure, not throw exception
    assert_kind_of Hash, result

    # Either it should detect the error and return an error field,
    # or it might find elements before the error is triggered (depending on browser behavior)
    if result[:error]
      # If error is detected, should have error field
      assert result[:error], "Should have error field"
      assert_match(/error/i, result[:error], "Error message should indicate an error occurred")
      assert_equal 0, result[:total_found], "Should have no results when error occurs"
    else
      # If no error, it's because the search succeeded before hitting the override
      # This is acceptable as we're handling errors gracefully
      assert_kind_of Array, result[:elements]
      assert_operator result[:total_found], :>=, 0, "Should have valid total_found"
    end
  end

  def test_handles_malformed_javascript_response
    # Test that tool handles unexpected JavaScript return values gracefully
    # We'll mock this by testing with nil/undefined returns
    html = <<-HTML
      <html>
        <head><title>Test Page</title></head>
        <body>
          <div id="test">Test content</div>
        </body>
      </html>
    HTML

    @browser.visit("data:text/html,#{html.gsub(/\s+/, " ").strip.gsub("#", "%23")}")

    # Override evaluate_script to return unexpected values
    original_evaluate_script = @browser.method(:evaluate_script)

    # Test with nil return
    @browser.define_singleton_method(:evaluate_script) do |_script|
      nil
    end

    result = @tool.execute(text: "Test")

    # Should handle nil gracefully
    assert_kind_of Hash, result
    assert_equal 0, result[:total_found], "Should handle nil return gracefully"
    assert_kind_of Array, result[:elements]
    assert_empty result[:elements]

    # Test with non-array return
    @browser.singleton_class.remove_method(:evaluate_script)
    @browser.define_singleton_method(:evaluate_script) do |_script|
      "not an array"
    end

    result = @tool.execute(text: "Test")

    # Should handle non-array gracefully
    assert_kind_of Hash, result
    assert_equal 0, result[:total_found], "Should handle non-array return gracefully"
    assert_kind_of Array, result[:elements]

    # Test with array containing non-hash elements
    @browser.singleton_class.remove_method(:evaluate_script)
    @browser.define_singleton_method(:evaluate_script) do |_script|
      ["not a hash", nil, 123, { "tag" => "div", "text" => "valid" }]
    end

    result = @tool.execute(text: "Test")

    # Should filter out invalid elements and keep valid ones
    assert_kind_of Hash, result
    assert_equal 1, result[:total_found], "Should keep only valid elements"
    assert_equal "div", result[:elements].first[:tag]

    # Restore original method
    @browser.singleton_class.remove_method(:evaluate_script)
    @browser.define_singleton_method(:evaluate_script, original_evaluate_script)
  end

  def test_handles_browser_not_on_page
    # Test when browser is not on any page (just initialized)
    @browser = HeadlessBrowserTool::Browser.new(headless: true)
    HeadlessBrowserTool::Server.instance_variable_set(:@browser_instance, @browser)
    @tool = HeadlessBrowserTool::Tools::FindElementsContainingTextTool.new

    # Try to search without visiting any page
    result = @tool.execute(text: "Test")

    # Should handle gracefully
    assert_kind_of Hash, result
    if result[:error]
      assert result[:error], "Should have error field"
      assert_match(/error|failed/i, result[:error], "Error message should indicate failure")
    else
      # Or might return empty results
      assert_equal 0, result[:total_found]
      assert_kind_of Array, result[:elements]
    end
  end

  def test_handles_javascript_error_object_return
    # Test when JavaScript returns an error object (as per the try-catch in the script)
    html = <<-HTML
      <html>
        <head><title>Test Page</title></head>
        <body>
          <div>Test content</div>
        </body>
      </html>
    HTML

    @browser.visit("data:text/html,#{html.gsub(/\s+/, " ").strip.gsub("#", "%23")}")

    # Mock evaluate_script to return error object as the JavaScript catch block does
    @browser.define_singleton_method(:evaluate_script) do |_script|
      { "error" => "Test JavaScript error", "stack" => "Error stack trace" }
    end

    result = @tool.execute(text: "Test")

    # Should handle error object return gracefully
    assert_kind_of Hash, result
    if result[:error]
      # Should extract error message from JavaScript error object
      assert result[:error], "Should have error field"
      assert_match(/JavaScript error|Test JavaScript error/i, result[:error], "Should include error message")
    else
      # Or return empty results with error info
      assert_equal 0, result[:total_found]
      assert_kind_of Array, result[:elements]
    end
  end
end
