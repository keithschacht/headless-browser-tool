# frozen_string_literal: true

require_relative "base_tool"

module HeadlessBrowserTool
  module Tools
    class GetPageContextTool < BaseTool
      tool_name "get_page_context"
      description "Analyze page structure and available actions. Returns metadata about navigation, forms, buttons, and page layout. " \
                  "Use this to understand what you can DO on a page (not for reading content)."

      def execute
        context_script = <<~JS
          (() => {
            // Helper to generate unique selector for elements
            const getUniqueSelector = (elem) => {
              if (elem.id) {
                return '#' + CSS.escape(elem.id);
              }

              if (elem.className && typeof elem.className === 'string') {
                const classes = elem.className.trim().split(/\\s+/)
                  .filter(c => c.length > 0)
                  .map(c => '.' + CSS.escape(c))
                  .join('');
                if (classes && document.querySelectorAll(elem.tagName + classes).length === 1) {
                  return elem.tagName.toLowerCase() + classes;
                }
              }

              // Build path from root
              const path = [];
              let current = elem;
              while (current && current.nodeType === Node.ELEMENT_NODE) {
                let selector = current.tagName.toLowerCase();
                if (current.id) {
                  selector = '#' + CSS.escape(current.id);
                  path.unshift(selector);
                  break;
                } else {
                  let sibling = current;
                  let nth = 1;
                  while (sibling.previousElementSibling) {
                    sibling = sibling.previousElementSibling;
                    if (sibling.tagName === current.tagName) nth++;
                  }
                  if (nth > 1) selector += ':nth-of-type(' + nth + ')';
                }
                path.unshift(selector);
                current = current.parentElement;
              }
              return path.join(' > ');
            };

            // Identify page type
            const identifyPageType = () => {
              const url = window.location.href;
              const title = document.title.toLowerCase();
              const h1 = document.querySelector('h1')?.textContent.toLowerCase() || '';

              if (url.includes('login') || title.includes('login') || h1.includes('login')) return 'login';
              if (url.includes('search') || title.includes('search')) return 'search_results';
              if (url.includes('cart') || title.includes('cart')) return 'shopping_cart';
              if (url.includes('checkout')) return 'checkout';
              if (document.querySelector('form[method="post"]')) return 'form_page';
              if (document.querySelectorAll('article').length > 3) return 'article_list';
              if (document.querySelector('article')) return 'article';
              return 'general';
            };

            // Get main navigation
            const getNavigation = () => {
              const nav = document.querySelector('nav') || document.querySelector('[role="navigation"]');
              if (!nav) return [];

              return Array.from(nav.querySelectorAll('a')).slice(0, 10).map((a, index) => ({
                text: a.textContent.trim(),
                href: a.href,
                selector: getUniqueSelector(a)
              }));
            };

            // Get actionable elements
            const getActions = () => {
              const actions = [];

              // Primary buttons
              document.querySelectorAll('button[type="submit"], button.primary, button.btn-primary').forEach(btn => {
                if (btn.offsetWidth > 0) {
                  actions.push({
                    type: 'primary_button',
                    text: btn.textContent.trim(),
                    selector: btn.className ? `.${btn.className.split(' ')[0]}` : 'button'
                  });
                }
              });

              // Forms
              document.querySelectorAll('form').forEach((form, index) => {
                const formInputs = Array.from(form.querySelectorAll('input:not([type="hidden"]), textarea, select'))
                  .map(input => ({
                    name: input.name || input.id,
                    type: input.type || 'text',
                    required: input.required,
                    value: input.value,
                    selector: getUniqueSelector(input)
                  }));

                if (formInputs.length > 0) {
                  actions.push({
                    type: 'form',
                    action: form.action,
                    method: form.method,
                    selector: getUniqueSelector(form),
                    inputs: formInputs
                  });
                }
              });

              return actions;
            };

            // Get key content areas
            const getContentAreas = () => {
              const areas = {};

              // Main content
              const main = document.querySelector('main') || document.querySelector('[role="main"]') || document.querySelector('#content');
              if (main) {
                areas.main = main.textContent.trim().substring(0, 200) + '...';
              }

              // Headings structure
              areas.headings = Array.from(document.querySelectorAll('h1, h2, h3')).slice(0, 10).map(h => ({
                level: h.tagName,
                text: h.textContent.trim(),
                selector: getUniqueSelector(h)
              }));

              // Errors or alerts
              const alerts = document.querySelectorAll('[role="alert"], .error, .alert, .warning, .success');
              if (alerts.length > 0) {
                areas.alerts = Array.from(alerts).map(a => ({
                  text: a.textContent.trim(),
                  selector: getUniqueSelector(a)
                }));
              }

              return areas;
            };

            // Get data attributes that might be useful
            const getDataAttributes = () => {
              const elements = document.querySelectorAll('[data-testid], [data-test], [data-cy]');
              return Array.from(elements).slice(0, 20).map(el => ({
                testId: el.dataset.testid || el.dataset.test || el.dataset.cy,
                tag: el.tagName.toLowerCase(),
                text: el.textContent.trim().substring(0, 50),
                selector: getUniqueSelector(el)
              }));
            };

            return {
              url: window.location.href,
              title: document.title,
              pageType: identifyPageType(),
              navigation: getNavigation(),
              actions: getActions(),
              contentAreas: getContentAreas(),
              testIds: getDataAttributes(),
              metrics: {
                loadTime: performance.timing.loadEventEnd - performance.timing.navigationStart,
                domElements: document.querySelectorAll('*').length,
                images: document.images.length,
                scripts: document.scripts.length
              }
            };
          })();
        JS

        context = browser.evaluate_script(context_script)
        return { error: "Unable to get page context" } if context.nil?

        # Return raw context data instead of formatted string
        context
      end
    end
  end
end
