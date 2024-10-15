syntax clear
for [icon_name, icon] in items(g:himalaya_ui_icons)
  if type(icon) ==? type({})
    for [nested_icon_name, nested_icon] in items(icon)
      let name = 'himalayaui_'.icon_name.'_'.nested_icon_name
      exe 'syn match '.name.' /^[[:blank:]]*'.escape(nested_icon, '*[]\/~').'/'
      exe 'hi default link '.name.' Directory'
    endfor
  else
    exe 'syn match himalayaui_'.icon_name. ' /^[[:blank:]]*'.escape(icon, '*[]\/~').'/'
  endif
endfor

exe 'syn match himalayaui_connection_source /\('.g:himalaya_ui_icons.expanded.himalaya.'\s\|'.g:himalaya_ui_icons.collapsed.himalaya.'\s\)\@<!([^)]*)$/'
exe 'syn match himalayaui_connection_ok /'.g:himalaya_ui_icons.connection_ok.'/'
exe 'syn match himalayaui_connection_error /'.g:himalaya_ui_icons.connection_error.'/'
syn match himalayaui_help /^".*$/
syn match himalayaui_help_key /^"\s\zs[^ ]*\ze\s-/ containedin=himalayaui_help
hi default link himalayaui_connection_source Comment
hi default link himalayaui_help Comment
hi default link himalayaui_help_key String
hi default link himalayaui_add_connection Directory
hi default link himalayaui_saved_list String
hi default link himalayaui_new_list Operator
hi default link himalayaui_buffers Constant
hi default link himalayaui_tables Constant
if &background ==? 'light'
  hi himalayaui_connection_ok guifg=#00AA00
  hi himalayaui_connection_error guifg=#AA0000
else
  hi himalayaui_connection_ok guifg=#88FF88
  hi himalayaui_connection_error guifg=#ff8888
endif
