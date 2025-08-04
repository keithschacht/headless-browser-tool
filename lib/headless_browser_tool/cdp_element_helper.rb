# frozen_string_literal: true

module HeadlessBrowserTool
  module CDPElementHelper # rubocop:disable Metrics/ModuleLength
    # Execute an action on an element via CDP
    def cdp_element_action(selector, action, value = nil)
      return yield unless @be_human && @cdp_initialized && cdp_available?

      begin
        case action
        when :click
          execute_cdp_script("document.querySelector('#{escape_selector(selector)}').click()")
        when :get_text
          execute_cdp_script("return document.querySelector('#{escape_selector(selector)}').textContent")
        when :get_value
          execute_cdp_script("return document.querySelector('#{escape_selector(selector)}').value")
        when :set_value
          execute_cdp_script(<<~JS)
            const el = document.querySelector('#{escape_selector(selector)}');
            el.value = '#{escape_js_string(value)}';
            el.dispatchEvent(new Event('input', { bubbles: true }));
            el.dispatchEvent(new Event('change', { bubbles: true }));
          JS
        when :focus
          execute_cdp_script("document.querySelector('#{escape_selector(selector)}').focus()")
        when :blur
          execute_cdp_script("document.querySelector('#{escape_selector(selector)}').blur()")
        when :submit_form
          execute_cdp_script("document.querySelector('#{escape_selector(selector)}').submit()")
        when :get_attribute
          execute_cdp_script("return document.querySelector('#{escape_selector(selector)}').getAttribute('#{value}')")
        when :set_attribute
          attr_name, attr_value = value
          execute_cdp_script("document.querySelector('#{escape_selector(selector)}').setAttribute('#{attr_name}', '#{escape_js_string(attr_value)}')")
        when :remove_attribute
          execute_cdp_script("document.querySelector('#{escape_selector(selector)}').removeAttribute('#{value}')")
        when :scroll_to
          execute_cdp_script("document.querySelector('#{escape_selector(selector)}').scrollIntoView({ behavior: 'smooth', block: 'center' })")
        when :hover
          execute_cdp_script(<<~JS)
            const el = document.querySelector('#{escape_selector(selector)}');
            const event = new MouseEvent('mouseover', {
              view: window,
              bubbles: true,
              cancelable: true
            });
            el.dispatchEvent(event);
          JS
        when :double_click
          execute_cdp_script(<<~JS)
            const el = document.querySelector('#{escape_selector(selector)}');
            const event = new MouseEvent('dblclick', {
              view: window,
              bubbles: true,
              cancelable: true
            });
            el.dispatchEvent(event);
          JS
        when :right_click
          execute_cdp_script(<<~JS)
            const el = document.querySelector('#{escape_selector(selector)}');
            const event = new MouseEvent('contextmenu', {
              view: window,
              bubbles: true,
              cancelable: true
            });
            el.dispatchEvent(event);
          JS
        when :check
          execute_cdp_script(<<~JS)
            const el = document.querySelector('#{escape_selector(selector)}');
            if (!el.checked) el.click();
          JS
        when :uncheck
          execute_cdp_script(<<~JS)
            const el = document.querySelector('#{escape_selector(selector)}');
            if (el.checked) el.click();
          JS
        when :select_option
          execute_cdp_script(<<~JS)
            const select = document.querySelector('#{escape_selector(selector)}');
            const option = Array.from(select.options).find(opt =>#{" "}
              opt.value === '#{escape_js_string(value)}' || opt.text === '#{escape_js_string(value)}'
            );
            if (option) {
              select.value = option.value;
              select.dispatchEvent(new Event('change', { bubbles: true }));
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
          # Find all matching elements
          execute_cdp_script(<<~JS)
            return Array.from(document.querySelectorAll('#{escape_selector(selector)}')).map((el, index) => ({
              selector: '#{escape_selector(selector)}:nth-of-type(' + (index + 1) + ')',
              text: el.textContent,
              tagName: el.tagName.toLowerCase()
            }));
          JS
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
