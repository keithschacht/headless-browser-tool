# frozen_string_literal: true

require "capybara"
require "capybara/dsl"
require "selenium-webdriver"
require "reverse_markdown"
require_relative "logger"
require_relative "human_mode"
require_relative "cdp_human"
require_relative "cdp_executor"
require_relative "cdp_context_manager"
require_relative "cdp_element_helper"
require_relative "session_persistence"

module HeadlessBrowserTool
  class Browser
    include HumanMode
    include CDPHuman
    include CDPElementHelper

    attr_reader :session
    attr_accessor :previous_state

    def initialize(headless: true, be_human: false, be_mostly_human: false)
      # Initialize logger if not already initialized
      HeadlessBrowserTool::Logger.initialize_logger(mode: :http) unless HeadlessBrowserTool::Logger.log

      @be_human = be_human
      @be_mostly_human = be_mostly_human
      @human_mode = be_human || be_mostly_human # Either flag enables human mode
      @session_id = "browser_#{object_id}"
      @driver_name = :"selenium_chrome_#{object_id}"
      configure_capybara(headless)
      @session = Capybara::Session.new(@driver_name)
      @previous_state = {}
      @cdp_initialized = false
      @cdp_setup_attempted = false
    end

    def active?
      !@session.driver.browser.nil?
    rescue StandardError
      false
    end

    # Navigation tools - delegate to session
    def visit(url)
      @session.visit(url)

      # Try to initialize CDP on first real navigation if in be_human mode (not mostly_human)
      if @be_human && !@cdp_setup_attempted && url != "about:blank"
        @cdp_setup_attempted = true
        # Small delay to ensure page has loaded
        sleep 0.1

        # setup_cdp now returns true/false instead of raising
        @cdp_initialized = setup_cdp(@session.driver.browser)

        if @cdp_initialized
          HeadlessBrowserTool::Logger.log.info "CDP human mode enabled on first navigation"
        else
          HeadlessBrowserTool::Logger.log.warn "CDP setup failed, using JS injection fallback"
        end

        # Always inject human JS as well (either as primary or fallback)
        inject_human_js(@session)
      elsif @be_mostly_human && !@cdp_setup_attempted && url != "about:blank"
        # For mostly_human, only inject human JS without CDP
        @cdp_setup_attempted = true # Mark as attempted so we don't run this again
        inject_human_js(@session)
        HeadlessBrowserTool::Logger.log.info "Human mode (without CDP) enabled on first navigation"
      end

      { message: "Navigated to #{url}" }
    end

    def refresh
      @session.refresh
      { message: "Page refreshed" }
    end

    def go_back
      @session.go_back
      { message: "Navigated back" }
    end

    def go_forward
      @session.go_forward
      { message: "Navigated forward" }
    end

    # Interaction tools
    def click(selector)
      cdp_element_action(selector, :click) do
        element = @session.find(selector)
        element.click
        { message: "Clicked element: #{selector}" }
      end
    end

    def right_click(selector)
      cdp_element_action(selector, :right_click) do
        element = @session.find(selector)
        element.right_click
        { message: "Right-clicked element: #{selector}" }
      end
    end

    def double_click(selector)
      cdp_element_action(selector, :double_click) do
        element = @session.find(selector)
        element.double_click
        { message: "Double-clicked element: #{selector}" }
      end
    end

    def hover(selector)
      cdp_element_action(selector, :hover) do
        element = @session.find(selector)
        element.hover
        { message: "Hovered over element: #{selector}" }
      end
    end

    def drag(source_selector, target_selector)
      source = @session.find(source_selector)
      target = @session.find(target_selector)
      source.drag_to(target)
      { message: "Dragged from #{source_selector} to #{target_selector}" }
    end

    # Element tools
    def find(selector, **)
      @session.find(selector, **)
    end

    def all(selector, **)
      @session.all(selector, **)
    end

    def find_button(locator, **)
      @session.find_button(locator, **)
    end

    def find_link(locator, **)
      @session.find_link(locator, **)
    end

    def find_field(locator, **)
      @session.find_field(locator, **)
    end

    def has_css?(selector, **)
      @session.has_css?(selector, **)
    end

    def has_selector?(selector, **)
      @session.has_selector?(selector, **)
    end

    def current_url
      @session.current_url
    end

    def find_element(selector)
      element = @session.find(selector)
      {
        tag_name: element.tag_name,
        text: element.text,
        visible: element.visible?,
        location: { x: element.native.location.x, y: element.native.location.y }
      }
    end

    def find_all(selector)
      cdp_find_elements(selector) do
        elements = @session.all(selector)
        elements.map do |element|
          {
            tag_name: element.tag_name,
            text: element.text,
            visible: element.visible?,
            attributes: extract_attributes(element),
            value: element.value
          }
        end
      end
    end

    def get_text(selector)
      cdp_element_action(selector, :get_text) do
        element = @session.find(selector)
        element.text
      end
    end

    def get_element_content(selector)
      cdp_element_action(selector, :get_element_content) do
        element = @session.find(selector)
        inner_html = element.native.attribute("innerHTML")
        md = ReverseMarkdown.convert(inner_html.gsub("\n", ""), unknown_tags: :bypass)
        {
          selector: selector,
          markdown: md,
          status: "success"
        }
      end
    end

    def get_attribute(selector, attribute_name)
      cdp_element_action(selector, :get_attribute, attribute_name) do
        element = @session.find(selector)
        element[attribute_name]
      end
    end

    def get_value(selector)
      cdp_element_action(selector, :get_value) do
        element = @session.find(selector)
        element.value
      end
    end

    def is_visible?(selector)
      element = @session.find(selector)
      element.visible?
    rescue Capybara::ElementNotFound
      false
    end

    def has_element?(selector, wait_seconds = nil)
      if wait_seconds
        @session.has_selector?(selector, wait: wait_seconds)
      else
        @session.has_selector?(selector)
      end
    end

    def has_text?(text, wait_seconds = nil)
      if wait_seconds
        @session.has_text?(text, wait: wait_seconds)
      else
        @session.has_text?(text)
      end
    end

    # Form tools
    def fill_in(field, value)
      cdp_element_action(field, :set_value, value) do
        @session.fill_in(field, with: value)
        { message: "Filled '#{field}' with '#{value}'" }
      end
    end

    def select(value, dropdown_selector)
      cdp_element_action(dropdown_selector, :select_option, value) do
        # Find the dropdown element first
        dropdown = @session.find(dropdown_selector)
        # Use Capybara's select method on the element
        dropdown.select(value)
        { message: "Selected '#{value}' from '#{dropdown_selector}'" }
      end
    end

    def check(checkbox_selector)
      cdp_element_action(checkbox_selector, :check) do
        # Find the checkbox element first
        checkbox = @session.find(checkbox_selector)
        # Use Capybara's check method on the element
        checkbox.set(true)
        { message: "Checked '#{checkbox_selector}'" }
      end
    end

    def uncheck(checkbox_selector)
      cdp_element_action(checkbox_selector, :uncheck) do
        # Find the checkbox element first
        checkbox = @session.find(checkbox_selector)
        # Use Capybara's uncheck method on the element
        checkbox.set(false)
        { message: "Unchecked '#{checkbox_selector}'" }
      end
    end

    def choose(radio_button_selector)
      cdp_element_action(radio_button_selector, :click) do
        # Find the radio button element first
        radio = @session.find(radio_button_selector)
        # Use Capybara's choose method on the element
        radio.set(true)
        { message: "Chose '#{radio_button_selector}'" }
      end
    end

    def attach_file(file_field_selector, file_path)
      # Find the file input element first
      file_input = @session.find(file_field_selector)
      # Use Capybara's attach_file method on the element
      file_input.set(file_path)
      { message: "Attached '#{file_path}' to '#{file_field_selector}'" }
    end

    def click_button(button_text_or_selector)
      cdp_element_action(button_text_or_selector, :click) do
        @session.click_button(button_text_or_selector)
        { message: "Clicked button: #{button_text_or_selector}" }
      end
    end

    def click_link(link_text_or_selector)
      cdp_element_action(link_text_or_selector, :click) do
        @session.click_link(link_text_or_selector)
        { message: "Clicked link: #{link_text_or_selector}" }
      end
    end

    # Info tools
    def get_current_url
      @session.current_url
    end

    def get_current_path
      @session.current_path
    end

    def get_page_title
      @session.title
    end

    def title
      @session.title
    end

    def get_page_source
      @session.html
    end

    # JavaScript tools
    def execute_script(javascript_code)
      if @be_human && @cdp_initialized && cdp_available?
        begin
          HeadlessBrowserTool::Logger.log.debug "[CDP] Attempting CDP execution..." if ENV["HBT_CDP_DEBUG"] == "true"
          execute_cdp_script(javascript_code)
          # Return the actual result from CDP execution
        rescue StandardError => e
          HeadlessBrowserTool::Logger.log.warn "CDP execution failed, falling back: #{e.message}"
          @session.execute_script(javascript_code)
        end
      else
        @session.execute_script(javascript_code)
      end
    end

    def evaluate_script(javascript_code)
      if @be_human && @cdp_initialized && cdp_available?
        begin
          execute_cdp_script(javascript_code)
        rescue StandardError => e
          HeadlessBrowserTool::Logger.log.warn "CDP evaluation failed, falling back: #{e.message}"
          @session.evaluate_script(javascript_code)
        end
      else
        @session.evaluate_script(javascript_code)
      end
    end

    # Utility tools
    def save_screenshot(file_path)
      @session.save_screenshot(file_path)
      { message: "Screenshot saved to #{file_path}" }
    end

    def save_page(file_path)
      @session.save_page(file_path)
      { message: "Page saved to #{file_path}" }
    end

    # Window tools
    def switch_to_window(window_handle)
      # Find the window object by handle
      window = @session.windows.find { |w| w.handle == window_handle }
      raise "Window with handle #{window_handle} not found" unless window

      @session.switch_to_window(window)
      current_window = @session.current_window

      {
        status: "success",
        window_handle: current_window.handle,
        current_url: @session.current_url,
        title: @session.title,
        position: get_window_position,
        size: get_window_size,
        is_current: true,
        total_windows: @session.windows.length
      }
    end

    def open_new_window
      initial_windows_count = @session.windows.length
      window = @session.open_new_window

      # Switch to the new window to get its info
      @session.switch_to_window(window)

      {
        status: "success",
        window_handle: window.handle,
        current_url: @session.current_url,
        title: @session.title,
        position: get_window_position,
        size: get_window_size,
        is_current: true,
        total_windows: @session.windows.length,
        previous_windows_count: initial_windows_count
      }
    end

    def close_window(window_handle)
      initial_windows_count = @session.windows.length
      current_handle = @session.current_window.handle

      # Support "current" as a special keyword
      window_handle = current_handle if window_handle == "current"

      window = @session.windows.find { |w| w.handle == window_handle }

      if window.nil?
        return {
          status: "error",
          error: "Window not found",
          window_handle: window_handle
        }
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
        raise unless e.message.include?("primary window")

        # Use Selenium driver directly to close the primary window
        # First switch to the window we want to close if not already there
        @session.switch_to_window(window) if window_handle != current_handle

        # Close using Selenium driver's close method
        @session.driver.browser.close

        # After closing, the session might be invalid if it was the last window
        # Try to switch to another window if any remain
        begin
          remaining_windows = @session.windows.reject { |w| w.handle == window_handle }
          @session.switch_to_window(remaining_windows.first) if remaining_windows.any?
        rescue Selenium::WebDriver::Error::InvalidSessionIdError
          # Session is terminated - this is expected when closing the last window
        end
      end

      # Save session state if we have a session_id
      begin
        SessionPersistence.save_session(@session_id, @session) if @session_id && defined?(SessionPersistence)
      rescue Selenium::WebDriver::Error::InvalidSessionIdError
        # Can't save if session is terminated
      end

      # Build response, handling potential invalid session
      begin
        remaining_count = @session.windows.length
        current_handle = @session.windows.any? ? @session.current_window.handle : nil
      rescue Selenium::WebDriver::Error::InvalidSessionIdError
        # Session terminated - no windows remain
        remaining_count = 0
        current_handle = nil
      end

      {
        status: "success",
        closed_window_handle: window_handle,
        remaining_windows: remaining_count,
        initial_windows_count: initial_windows_count,
        current_window_handle: current_handle
      }
    end

    def get_window_handles
      @session.windows.map(&:handle)
    end

    def current_window_handle
      @session.current_window.handle
    end

    def maximize_window
      current_window = @session.current_window
      size_before = get_window_size

      current_window.maximize

      size_after = get_window_size

      {
        status: "success",
        window_handle: current_window.handle,
        size_before: size_before,
        size_after: size_after,
        current_url: @session.current_url,
        title: @session.title
      }
    end

    def resize_window(width, height)
      current_window = @session.current_window
      size_before = get_window_size

      current_window.resize_to(width, height)

      size_after = get_window_size

      {
        status: "success",
        window_handle: current_window.handle,
        size_before: size_before,
        size_after: size_after,
        requested_size: { width: width, height: height },
        actual_size: size_after,
        current_url: @session.current_url,
        title: @session.title
      }
    end

    def current_window
      @session.current_window
    end

    def text
      @session.text
    end

    def windows
      @session.windows
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

    def get_window_size
      size = @session.current_window.size
      { width: size[0], height: size[1] }
    rescue StandardError
      { width: nil, height: nil }
    end

    def get_window_position
      # Try to get window position, but this might not be supported by all drivers

      browser = @session.driver.browser
      position = browser.manage.window.position
      { x: position.x, y: position.y }
    rescue StandardError
      { x: nil, y: nil }
    end

    def configure_capybara(headless)
      Capybara.register_driver @driver_name do |app|
        options = Selenium::WebDriver::Chrome::Options.new
        options.add_argument("--headless") if headless
        options.add_argument("--no-sandbox")
        options.add_argument("--disable-dev-shm-usage")
        options.add_argument("--disable-gpu") if headless

        # Apply human-like browser options if enabled (for both be_human and be_mostly_human)
        if @human_mode
          options.add_argument("--disable-blink-features=AutomationControlled")
          # Exclude the enable-automation switch
          options.exclude_switches << "enable-automation"
          options.add_preference("credentials_enable_service", false)
          options.add_preference("profile.password_manager_enabled", false)

          # Window configuration - just use start-maximized like a normal user
          options.add_argument("--start-maximized")

          # Don't override user agent - Chrome's default works perfectly!
        end

        Capybara::Selenium::Driver.new(app, browser: :chrome, options: options)
      end

      # Don't set global defaults - each session uses its own driver
    end
  end
end
