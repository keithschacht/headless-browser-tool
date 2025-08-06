# frozen_string_literal: true

module HeadlessBrowserTool
  module CDPElementHelper # rubocop:disable Metrics/ModuleLength
    # Execute an action on an element via CDP
    def cdp_element_action(selector, action, value = nil)
      return yield unless @be_human && @cdp_initialized && cdp_available?

      begin
        # Build a JavaScript function that finds elements similar to how Capybara does
        # This stays entirely within CDP context to avoid detection
        find_element_js = <<~JS
          (function() {
            const selector = '#{escape_selector(selector)}';
            
            // First try as a CSS selector
            let el = document.querySelector(selector);
            if (el) return el;
            
            // Try by ID (without #)
            el = document.getElementById(selector);
            if (el) return el;
            
            // Try by name attribute
            el = document.querySelector(`[name="${selector}"]`);
            if (el) return el;
            
            // Try by placeholder
            el = document.querySelector(`[placeholder="${selector}"]`);
            if (el) return el;
            
            // Try by label text (for form fields)
            const labels = document.querySelectorAll('label');
            for (const label of labels) {
              if (label.textContent.trim() === selector) {
                const forId = label.getAttribute('for');
                if (forId) {
                  el = document.getElementById(forId);
                  if (el) return el;
                }
                // Check if input is nested in label
                el = label.querySelector('input, textarea, select');
                if (el) return el;
              }
            }
            
            // Try button by text
            const buttons = document.querySelectorAll('button, input[type="button"], input[type="submit"]');
            for (const btn of buttons) {
              if (btn.textContent.trim() === selector || btn.value === selector) {
                return btn;
              }
            }
            
            // Try link by text
            const links = document.querySelectorAll('a');
            for (const link of links) {
              if (link.textContent.trim() === selector) {
                return link;
              }
            }
            
            return null;
          })()
        JS

        case action
        when :click
          execute_cdp_script("(#{find_element_js})?.click()")
        when :get_text
          execute_cdp_script("return (#{find_element_js})?.textContent")
        when :get_value
          execute_cdp_script("return (#{find_element_js})?.value")
        when :set_value
          execute_cdp_script(<<~JS)
            const el = #{find_element_js};
            if (el) {
              el.value = '#{escape_js_string(value)}';
              el.dispatchEvent(new Event('input', { bubbles: true }));
              el.dispatchEvent(new Event('change', { bubbles: true }));
            }
          JS
        when :focus
          execute_cdp_script("(#{find_element_js})?.focus()")
        when :blur
          execute_cdp_script("(#{find_element_js})?.blur()")
        when :submit_form
          execute_cdp_script("(#{find_element_js})?.submit()")
        when :get_attribute
          execute_cdp_script("return (#{find_element_js})?.getAttribute('#{value}')")
        when :set_attribute
          attr_name, attr_value = value
          execute_cdp_script("(#{find_element_js})?.setAttribute('#{attr_name}', '#{escape_js_string(attr_value)}')")
        when :remove_attribute
          execute_cdp_script("(#{find_element_js})?.removeAttribute('#{value}')")
        when :scroll_to
          execute_cdp_script("(#{find_element_js})?.scrollIntoView({ behavior: 'smooth', block: 'center' })")
        when :hover
          execute_cdp_script(<<~JS)
            const el = #{find_element_js};
            if (el) {
              const event = new MouseEvent('mouseover', {
                view: window,
                bubbles: true,
                cancelable: true
              });
              el.dispatchEvent(event);
            }
          JS
        when :double_click
          execute_cdp_script(<<~JS)
            const el = #{find_element_js};
            if (el) {
              const event = new MouseEvent('dblclick', {
                view: window,
                bubbles: true,
                cancelable: true
              });
              el.dispatchEvent(event);
            }
          JS
        when :right_click
          execute_cdp_script(<<~JS)
            const el = #{find_element_js};
            if (el) {
              const event = new MouseEvent('contextmenu', {
                view: window,
                bubbles: true,
                cancelable: true
              });
              el.dispatchEvent(event);
            }
          JS
        when :check
          execute_cdp_script(<<~JS)
            const el = #{find_element_js};
            if (el && !el.checked) el.click();
          JS
        when :uncheck
          execute_cdp_script(<<~JS)
            const el = #{find_element_js};
            if (el && el.checked) el.click();
          JS
        when :select_option
          execute_cdp_script(<<~JS)
            const select = #{find_element_js};
            if (select) {
              const option = Array.from(select.options).find(opt =>#{" "}
                opt.value === '#{escape_js_string(value)}' || opt.text === '#{escape_js_string(value)}'
              );
              if (option) {
                select.value = option.value;
                select.dispatchEvent(new Event('change', { bubbles: true }));
              }
            }
          JS
        else
          # Fallback to regular Selenium
          yield
        end
      rescue StandardError => e
        HeadlessBrowserTool::Logger.log.warn "CDP element action failed, falling back: #{e.message}"
        yield
      end
    end

    # Find elements via CDP
    def cdp_find_elements(selector, options = {})
      return yield unless @be_human && @cdp_initialized && cdp_available?

      begin
        if options[:text]
          # Find by text content
          execute_cdp_script(<<~JS)
            return Array.from(document.querySelectorAll('#{escape_selector(selector)}')).filter(el =>#{" "}
              el.textContent.includes('#{escape_js_string(options[:text])}')
            ).map((el, index) => ({
              selector: '#{escape_selector(selector)}:nth-of-type(' + (index + 1) + ')',
              text: el.textContent,
              tagName: el.tagName.toLowerCase()
            }));
          JS
        else
          # For regular find_all, use CDP to touch elements (for anti-bot avoidance)
          # but then use Capybara to get the actual data in the correct format
          execute_cdp_script(<<~JS)
            // Touch the elements via CDP to appear human-like
            const elements = document.querySelectorAll('#{escape_selector(selector)}');
            // Just accessing them is enough for anti-bot avoidance
            elements.forEach(el => el.tagName);
            return elements.length;
          JS

          # After CDP touch, use Capybara to get the actual data
          # This ensures we get the correct format while still being undetectable
          yield
        end
      rescue StandardError => e
        HeadlessBrowserTool::Logger.log.warn "CDP find elements failed, falling back: #{e.message}"
        yield
      end
    end

    private

    def escape_selector(selector)
      selector.gsub("'", "\\\\'").gsub('"', '\\"')
    end

    def escape_js_string(str)
      return "" if str.nil?

      str.to_s.gsub("\\", "\\\\\\\\").gsub("'", "\\\\'").gsub('"', '\\"').gsub("\n", "\\n").gsub("\r", "\\r")
    end
  end # rubocop:enable Metrics/ModuleLength
end
