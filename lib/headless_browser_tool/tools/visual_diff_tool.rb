# frozen_string_literal: true

require_relative "base_tool"

module HeadlessBrowserTool
  module Tools
    class VisualDiffTool < BaseTool
      tool_name "visual_diff"
      description "Capture what changed on the page after an action"

      def execute
        # Capture current state
        current_state = capture_page_state

        # Compare with previous state if exists
        previous_state = browser.previous_state || {}

        changes = {
          url_changed: previous_state[:url] != current_state[:url],
          title_changed: previous_state[:title] != current_state[:title],
          new_elements: find_new_elements(previous_state[:elements], current_state[:elements]),
          removed_elements: find_removed_elements(previous_state[:elements], current_state[:elements]),
          text_changes: find_text_changes(previous_state[:texts], current_state[:texts]),
          form_values_changed: compare_form_values(previous_state[:forms], current_state[:forms]),
          new_images: current_state[:images] - (previous_state[:images] || []),
          viewport_position: current_state[:scroll]
        }

        # Store current state for next comparison
        browser.previous_state = current_state

        # Return human-readable summary
        summarize_changes(changes, current_state)
      end

      private

      def capture_page_state
        state_script = <<~JS
          (() => {
            // Get all visible text nodes
            const texts = [];
            const walker = document.createTreeWalker(
              document.body,
              NodeFilter.SHOW_TEXT,
              {
                acceptNode: (node) => {
                  const parent = node.parentElement;
                  if (parent && parent.offsetWidth > 0 && parent.offsetHeight > 0) {
                    const text = node.textContent.trim();
                    if (text.length > 0) return NodeFilter.FILTER_ACCEPT;
                  }
                  return NodeFilter.FILTER_REJECT;
                }
              }
            );

            let node;
            while (node = walker.nextNode()) {
              texts.push(node.textContent.trim());
            }

            // Get form values
            const forms = {};
            document.querySelectorAll('input, select, textarea').forEach(el => {
              if (el.name || el.id) {
                forms[el.name || el.id] = el.value;
              }
            });

            // Get interactive elements count
            const elements = {
              buttons: document.querySelectorAll('button, [role="button"]').length,
              links: document.querySelectorAll('a[href]').length,
              inputs: document.querySelectorAll('input, textarea, select').length,
              images: document.querySelectorAll('img').length
            };

            // Get images
            const images = Array.from(document.querySelectorAll('img')).map(img => img.alt || img.src);

            return {
              url: window.location.href,
              title: document.title,
              texts: texts,
              forms: forms,
              elements: elements,
              images: images,
              scroll: { x: window.scrollX, y: window.scrollY }
            };
          })();
        JS

        state = browser.evaluate_script(state_script)
        state || {}
      end

      def find_new_elements(old_elements, new_elements)
        return {} unless old_elements && new_elements

        changes = {}
        new_elements.each do |key, count|
          old_count = old_elements[key] || 0
          changes[key] = count - old_count if count > old_count
        end
        changes
      end

      def find_removed_elements(old_elements, new_elements)
        return {} unless old_elements && new_elements

        changes = {}
        old_elements.each do |key, count|
          new_count = new_elements[key] || 0
          changes[key] = count - new_count if count > new_count
        end
        changes
      end

      def find_text_changes(old_texts, new_texts)
        return [] unless old_texts && new_texts

        # Find completely new text blocks
        new_text_blocks = new_texts - old_texts
        new_text_blocks.select { |text| text.length > 20 } # Only significant text
      end

      def compare_form_values(old_forms, new_forms)
        return {} unless old_forms && new_forms

        changes = {}
        new_forms.each do |field, value|
          changes[field] = { from: old_forms[field], to: value } if old_forms[field] != value && !value.empty?
        end
        changes
      end

      def summarize_changes(changes, current_state)
        summary = []

        # URL change
        summary << "📍 Navigated to: #{current_state[:url]}" if changes[:url_changed]

        # Title change
        summary << "📄 Page title: \"#{current_state[:title]}\"" if changes[:title_changed]

        # New elements appeared
        if changes[:new_elements].any?
          changes[:new_elements].each do |type, count|
            summary << "➕ #{count} new #{type} appeared"
          end
        end

        # Elements removed
        if changes[:removed_elements].any?
          changes[:removed_elements].each do |type, count|
            summary << "➖ #{count} #{type} removed"
          end
        end

        # Form changes
        summary << "✏️ Form fields updated: #{changes[:form_values_changed].keys.join(", ")}" if changes[:form_values_changed].any?

        # New significant text
        summary << "💬 New text appeared: \"#{changes[:text_changes].first[0..100]}...\"" if changes[:text_changes].any?

        # Scroll position
        summary << "📜 Page scrolled to position: #{changes[:viewport_position][:y]}px" if changes[:viewport_position][:y] > 100

        # If no changes detected
        summary << "No significant visual changes detected" if summary.empty?

        summary.join("\n")
      end
    end
  end
end
