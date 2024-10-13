if get(g:, 'himalaya_ui_disable_mappings', 0) || get(g:, 'himalaya_ui_disable_mappings_sql', 0)
  finish
endif

call himalaya_ui#utils#set_mapping('<Leader>W', '<Plug>(HIMALAYAUI_SaveQuery)')
call himalaya_ui#utils#set_mapping('<Leader>E', '<Plug>(HIMALAYAUI_EditBindParameters)')
call himalaya_ui#utils#set_mapping('<Leader>S', '<Plug>(HIMALAYAUI_ExecuteQuery)')
call himalaya_ui#utils#set_mapping('<Leader>S', '<Plug>(HIMALAYAUI_ExecuteQuery)', 'v')
