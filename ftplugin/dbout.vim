nnoremap <silent><buffer> <Plug>(HIMALAYAUI_JumpToForeignKey) :call himalaya_ui#himalayaout#jump_to_foreign_table()<CR>
nnoremap <silent><buffer> <Plug>(HIMALAYAUI_YankCellValue) :call himalaya_ui#himalayaout#get_cell_value()<CR>
nnoremap <silent><buffer> <Plug>(HIMALAYAUI_YankHeader) :call himalaya_ui#himalayaout#yank_header()<CR>
nnoremap <silent><buffer> <Plug>(HIMALAYAUI_ToggleResultLayout) :call himalaya_ui#himalayaout#toggle_layout()<CR>
omap <silent><buffer> ic :call himalaya_ui#himalayaout#get_cell_value()<CR>

if get(g:, 'himalaya_ui_disable_mappings', 0) || get(g:, 'himalaya_ui_disable_mappings_himalayaout', 0)
  finish
endif

call himalaya_ui#utils#set_mapping('<C-]>', '<Plug>(HIMALAYAUI_JumpToForeignKey)')
call himalaya_ui#utils#set_mapping('vic', '<Plug>(HIMALAYAUI_YankCellValue)')
call himalaya_ui#utils#set_mapping('yh', '<Plug>(HIMALAYAUI_YankHeader)')
call himalaya_ui#utils#set_mapping('<Leader>R', '<Plug>(HIMALAYAUI_ToggleResultLayout)')
