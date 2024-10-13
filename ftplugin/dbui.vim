if get(g:, 'himalaya_ui_disable_mappings', 0) || get(g:, 'himalaya_ui_disable_mappings_himalayaui', 0)
  finish
endif

call himalaya_ui#utils#set_mapping(['o', '<CR>', '<2-LeftMouse>'], '<Plug>(HIMALAYAUI_SelectLine)')
call himalaya_ui#utils#set_mapping('S', '<Plug>(HIMALAYAUI_SelectLineVsplit)')
call himalaya_ui#utils#set_mapping('R', '<Plug>(HIMALAYAUI_Redraw)')
call himalaya_ui#utils#set_mapping('d', '<Plug>(HIMALAYAUI_DeleteLine)')
call himalaya_ui#utils#set_mapping('A', '<Plug>(HIMALAYAUI_AddConnection)')
call himalaya_ui#utils#set_mapping('H', '<Plug>(HIMALAYAUI_ToggleDetails)')
call himalaya_ui#utils#set_mapping('r', '<Plug>(HIMALAYAUI_RenameLine)')
call himalaya_ui#utils#set_mapping('q', '<Plug>(HIMALAYAUI_Quit)')
call himalaya_ui#utils#set_mapping('<c-k>', '<Plug>(HIMALAYAUI_GotoFirstSibling)')
call himalaya_ui#utils#set_mapping('<c-j>', '<Plug>(HIMALAYAUI_GotoLastSibling)')
call himalaya_ui#utils#set_mapping('<C-p>', '<Plug>(HIMALAYAUI_GotoParentNode)')
call himalaya_ui#utils#set_mapping('<C-n>', '<Plug>(HIMALAYAUI_GotoChildNode)')
call himalaya_ui#utils#set_mapping('K', '<Plug>(HIMALAYAUI_GotoPrevSibling)')
call himalaya_ui#utils#set_mapping('J', '<Plug>(HIMALAYAUI_GotoNextSibling)')
