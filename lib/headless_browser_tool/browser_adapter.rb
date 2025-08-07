# frozen_string_literal: true

module HeadlessBrowserTool
  # Adapter to make Capybara::Session compatible with our Browser interface
  class BrowserAdapter
    attr_reader :session, :session_id
    attr_accessor :previous_state

    def initialize(capybara_session, session_id)
      @session = capybara_session
      @session_id = session_id
      @previous_state = {}
    end

    # Navigation methods
    def visit(url)
      @session.visit(url)
    end

    def refresh
      @session.refresh
    end

    def go_back
      @session.go_back
    end

    def go_forward
      @session.go_forward
    end

    # Finding elements
    def find(selector, **)
      @session.find(selector, **)
    end

    # Alias for compatibility with our tools - just needs to not throw error
    def find_element(selector)
      @session.find(selector)
      # Tool will return its own message
    end

    def all(selector, **)
      @session.all(selector, **)
    end

    def has_selector?(selector, **)
      @session.has_selector?(selector, **)
    end

    def find_button(locator, **)
      @session.find_button(locator, **)
    end

    def has_no_selector?(selector, **)
      @session.has_no_selector?(selector, **)
    end

    def has_text?(text, **)
      @session.has_text?(text, **)
    end

    def has_no_text?(text, **)
      @session.has_no_text?(text, **)
    end

    # Interaction methods
    def click(selector)
      element = @session.find(selector)
      element.click
    end

    def click_on(locator, **)
      @session.click_on(locator, **)
    end

    def fill_in(field, value)
      # Match original Browser class signature
      @session.fill_in(field, with: value)
    end

    def choose(locator, **)
      @session.choose(locator, **)
    end

    def check(locator, **)
      @session.check(locator, **)
    end

    def uncheck(locator, **)
      @session.uncheck(locator, **)
    end

    def select(value, dropdown_selector = nil, from: nil, **)
      # Support both signatures: select(value, dropdown) and select(value, from: dropdown)
      from ||= dropdown_selector
      @session.select(value, from: from, **)
    end

    def attach_file(locator, path, **)
      @session.attach_file(locator, path, **)
    end

    # Additional methods to match Browser class
    def get_text(selector)
      @session.find(selector).text
    end

    def get_attribute(selector, attribute_name)
      @session.find(selector)[attribute_name]
    end

    def get_value(selector)
      @session.find(selector).value
    end

    def is_visible?(selector)
      @session.find(selector).visible?
    rescue Capybara::ElementNotFound
      false
    end

    def has_element?(selector, wait = nil)
      if wait
        @session.has_selector?(selector, wait: wait)
      else
        @session.has_selector?(selector)
      end
    end

    def click_button(button_text_or_selector)
      @session.click_button(button_text_or_selector)
    end

    def click_link(link_text_or_selector)
      @session.click_link(link_text_or_selector)
    end

    def right_click(selector)
      @session.find(selector).right_click
    end

    def double_click(selector)
      @session.find(selector).double_click
    end

    def hover(selector)
      @session.find(selector).hover
    end

    def drag(source_selector, target_selector)
      source = @session.find(source_selector)
      target = @session.find(target_selector)
      source.drag_to(target)
    end

    def find_all(selector)
      @session.all(selector).map do |element|
        {
          tag_name: element.tag_name,
          text: element.text,
          visible: element.visible?,
          attributes: extract_attributes(element),
          value: element.value
        }
      end
    end

    def get_current_url
      @session.current_url
    end

    def get_current_path
      @session.current_path
    end

    def get_page_title
      @session.title
    end

    def get_page_source
      @session.html
    end

    def get_window_handles
      @session.windows.map(&:handle)
    end

    def switch_to_window(window_handle)
      @session.switch_to_window(window_handle)
    end

    def resize_window(width, height)
      @session.current_window.resize_to(width, height)
    end

    # JavaScript execution
    def execute_script(script, *)
      @session.execute_script(script, *)
    end

    def evaluate_script(script, *)
      @session.evaluate_script(script, *)
    end

    # Screenshots
    def save_screenshot(path, **)
      @session.save_screenshot(path, **)
    end

    def save_page(path, **)
      @session.save_page(path, **)
    end

    # Window management
    def current_window
      @session.current_window
    end

    def windows
      @session.windows
    end

    def open_new_window
      new_window = @session.open_new_window
      @session.switch_to_window(new_window)
      new_window
    end

    def close_window(window_handle)
      HeadlessBrowserTool::Logger.log.info "[BrowserAdapter] === Starting close_window operation ===" if defined?(HeadlessBrowserTool::Logger)
      initial_windows_count = @session.windows.length
      current_handle = @session.current_window.handle
      HeadlessBrowserTool::Logger.log.info "[BrowserAdapter] Initial windows: #{initial_windows_count}, Current handle: #{current_handle}" if defined?(HeadlessBrowserTool::Logger)

      # Support "current" as a special keyword
      window_handle = current_handle if window_handle == "current"
      HeadlessBrowserTool::Logger.log.info "[BrowserAdapter] Window to close: #{window_handle}" if defined?(HeadlessBrowserTool::Logger)

      window = @session.windows.find { |w| w.handle == window_handle }

      if window.nil?
        return {
          status: "error",
          error: "Window not found",
          window_handle: window_handle
        }
      end

      # Save session state BEFORE closing the window
      # This ensures we capture the correct state
      HeadlessBrowserTool::Logger.log.info "[BrowserAdapter] Checking session save: session_id=#{@session_id.inspect}, SessionPersistence defined=#{defined?(SessionPersistence)}" if defined?(HeadlessBrowserTool::Logger)
      if @session_id && defined?(SessionPersistence)
        HeadlessBrowserTool::Logger.log.info "[BrowserAdapter] Saving session with ID: #{@session_id}" if defined?(HeadlessBrowserTool::Logger)
        SessionPersistence.save_session(@session_id, @session)
      else
        HeadlessBrowserTool::Logger.log.info "[BrowserAdapter] Skipping session save - no session_id or SessionPersistence not defined" if defined?(HeadlessBrowserTool::Logger)
      end

      # If closing the current window, switch to another first
      if window_handle == current_handle && @session.windows.length > 1
        other_window = @session.windows.find { |w| w.handle != window_handle }
        @session.switch_to_window(other_window) if other_window
      end

      begin
        window.close
      rescue ArgumentError => e
        # Capybara raises ArgumentError when trying to close the primary window
        # We'll allow it and return success
        raise unless e.message.include?("primary window")
        # This is fine - just means we're closing the last window

        # Re-raise if it's a different ArgumentError
      end

      # Session already saved before closing - no need to save again

      {
        status: "success",
        closed_window_handle: window_handle,
        remaining_windows: @session.windows.length,
        initial_windows_count: initial_windows_count,
        current_window_handle: @session.windows.any? ? @session.current_window.handle : nil
      }
    end

    def window_handles
      @session.windows.map(&:handle)
    end

    def maximize_window
      @session.current_window.maximize
    end

    def resize_window_to(width, height)
      @session.current_window.resize_to(width, height)
    end

    # Aliases to match our original Browser interface
    alias resize_to resize_window_to

    # Page information
    def current_url
      @session.current_url
    end

    def current_path
      @session.current_path
    end

    def title
      @session.title
    end

    def html
      @session.html
    end

    def text
      @session.text
    end

    # Capybara-specific delegations
    def within(*, &)
      @session.within(*, &)
    end

    def within_window(window, &)
      @session.within_window(window, &)
    end

    def accept_alert(&)
      @session.accept_alert(&)
    end

    def dismiss_alert(&)
      @session.dismiss_alert(&)
    end

    def accept_confirm(&)
      @session.accept_confirm(&)
    end

    def dismiss_confirm(&)
      @session.dismiss_confirm(&)
    end

    # Driver access (for advanced operations)
    def driver
      @session.driver
    end

    # Cleanup
    def quit
      @session.quit
    end

    def reset!
      @session.reset!
    end

    private

    def extract_attributes(element)
      # Get common attributes that are often useful
      attrs = {}
      %w[id class href src alt title name type value placeholder data-testid role aria-label].each do |attr|
        value = element[attr]
        attrs[attr] = value if value && !value.empty?
      end
      attrs
    end
  end
end
