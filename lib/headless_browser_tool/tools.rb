# frozen_string_literal: true

require_relative "tools/base_tool"
require_relative "tools/visit_tool"
require_relative "tools/refresh_tool"
require_relative "tools/go_back_tool"
require_relative "tools/go_forward_tool"
require_relative "tools/click_tool"
require_relative "tools/right_click_tool"
require_relative "tools/double_click_tool"
require_relative "tools/hover_tool"
require_relative "tools/drag_tool"
require_relative "tools/find_element_tool"
require_relative "tools/find_all_tool"
require_relative "tools/find_elements_containing_text_tool"
require_relative "tools/get_text_tool"
require_relative "tools/get_element_content_tool"
require_relative "tools/get_attribute_tool"
require_relative "tools/get_value_tool"
require_relative "tools/is_visible_tool"
require_relative "tools/has_element_tool"
require_relative "tools/has_text_tool"
require_relative "tools/fill_in_tool"
require_relative "tools/select_tool"
require_relative "tools/check_tool"
require_relative "tools/uncheck_tool"
require_relative "tools/choose_tool"
require_relative "tools/attach_file_tool"
require_relative "tools/click_button_tool"
require_relative "tools/click_link_tool"
require_relative "tools/get_current_url_tool"
require_relative "tools/get_current_path_tool"
require_relative "tools/get_page_title_tool"
require_relative "tools/get_page_source_tool"
require_relative "tools/execute_script_tool"
require_relative "tools/evaluate_script_tool"
require_relative "tools/save_page_tool"
require_relative "tools/switch_to_window_tool"
require_relative "tools/open_new_window_tool"
require_relative "tools/close_window_tool"
require_relative "tools/get_window_handles_tool"
require_relative "tools/maximize_window_tool"
require_relative "tools/resize_window_tool"
require_relative "tools/screenshot_tool"
require_relative "tools/search_page_tool"
require_relative "tools/search_source_tool"
require_relative "tools/visual_diff_tool"
require_relative "tools/get_page_context_tool"
require_relative "tools/auto_narrate_tool"
require_relative "tools/get_narration_history_tool"
require_relative "tools/get_session_info_tool"
require_relative "tools/about_tool"

module HeadlessBrowserTool
  module Tools
    ALL_TOOLS = [
      VisitTool,
      RefreshTool,
      GoBackTool,
      GoForwardTool,
      ClickTool,
      RightClickTool,
      DoubleClickTool,
      HoverTool,
      DragTool,
      FindElementTool,
      FindAllTool,
      FindElementsContainingTextTool,
      GetTextTool,
      GetElementContentTool,
      GetAttributeTool,
      GetValueTool,
      IsVisibleTool,
      HasElementTool,
      HasTextTool,
      FillInTool,
      SelectTool,
      CheckTool,
      UncheckTool,
      ChooseTool,
      AttachFileTool,
      ClickButtonTool,
      ClickLinkTool,
      GetCurrentUrlTool,
      GetCurrentPathTool,
      GetPageTitleTool,
      GetPageSourceTool,
      ExecuteScriptTool,
      EvaluateScriptTool,
      SavePageTool,
      SwitchToWindowTool,
      OpenNewWindowTool,
      CloseWindowTool,
      GetWindowHandlesTool,
      MaximizeWindowTool,
      ResizeWindowTool,
      ScreenshotTool,
      SearchPageTool,
      SearchSourceTool,
      VisualDiffTool,
      GetPageContextTool,
      AutoNarrateTool,
      GetNarrationHistoryTool,
      GetSessionInfoTool,
      AboutTool
    ].freeze
  end
end
