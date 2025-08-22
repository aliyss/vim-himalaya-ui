

if exists('g:loaded_himalayaui')
  finish
endif

let g:loaded_himalayaui = 1

let default_executable = 'himalaya'
let g:himalaya_executable = get(g:, 'himalaya_executable', default_executable)

if !executable(g:himalaya_executable)
  throw 'Himalaya CLI not found, see https://pimalaya.org/himalaya/cli/latest/installation/'
endif

let g:himalaya_ui_disable_progress_bar = get(g:, 'himalaya_ui_disable_progress_bar', 0)
let g:himalaya_ui_use_postgres_views = get(g:, 'himalaya_ui_use_postgres_views', 1)
let g:himalaya_ui_notification_width = get(g:, 'himalaya_ui_notification_width', 40)
let g:himalaya_ui_winwidth = get(g:, 'himalaya_ui_winwidth', 40)
let g:himalaya_ui_win_position = get(g:, 'himalaya_ui_win_position', 'left')
let g:himalaya_ui_default_list = get(g:, 'himalaya_ui_default_list', 'SELECT * from "{table}" LIMIT 200;')
let g:himalaya_ui_save_location = get(g:, 'himalaya_ui_save_location', '~/.local/share/himalaya_ui')
let g:himalaya_ui_tmp_list_location = get(g:, 'himalaya_ui_tmp_list_location', '')
let g:himalaya_ui_dotenv_variable_prefix = get(g:, 'himalaya_ui_dotenv_variable_prefix', 'HIMALAYA_UI_')
let g:himalaya_ui_env_variable_url = get(g:, 'himalaya_ui_env_variable_url', 'HIMALAYAUI_URL')
let g:himalaya_ui_env_variable_name = get(g:, 'himalaya_ui_env_variable_name', 'HIMALAYAUI_NAME')
let g:himalaya_ui_disable_mappings = get(g:, 'himalaya_ui_disable_mappings', 0)
let g:himalaya_ui_disable_mappings_himalayaui = get(g:, 'himalaya_ui_disable_mappings_himalayaui', 0)
let g:himalaya_ui_disable_mappings_himalayaout = get(g:, 'himalaya_ui_disable_mappings_himalayaout', 0)
let g:himalaya_ui_disable_mappings_sql = get(g:, 'himalaya_ui_disable_mappings_sql', 0)
let g:himalaya_ui_disable_mappings_javascript = get(g:, 'himalaya_ui_disable_mappings_javascript', 0)
let g:himalaya_ui_table_helpers = get(g:, 'himalaya_ui_table_helpers', {})
let g:himalaya_ui_auto_execute_table_helpers = get(g:, 'himalaya_ui_auto_execute_table_helpers', 0)
let g:himalaya_ui_show_help = get(g:, 'himalaya_ui_show_help', 1)
let g:himalaya_ui_use_nerd_fonts = get(g:, 'himalaya_ui_use_nerd_fonts', 0)
let g:himalaya_ui_execute_on_save = get(g:, 'himalaya_ui_execute_on_save', 1)
let g:himalaya_ui_force_echo_notifications = get(g:, 'himalaya_ui_force_echo_notifications', 0)
let g:himalaya_ui_use_nvim_notify = get(g:, 'himalaya_ui_use_nvim_notify', 0)
let g:himalaya_ui_buffer_name_generator = get(g:, 'himalaya_ui_buffer_name_generator', 0)
let g:himalaya_ui_debug = get(g:, 'himalaya_ui_debug', 0)
let g:himalaya_ui_hide_schemas = get(g:, 'himalaya_ui_hide_schemas', [])
let g:himalaya_ui_bind_param_pattern = get(g: , 'himalaya_ui_bind_param_pattern', ':\w\+')
let g:himalaya_ui_is_oracle_legacy = get(g:, 'himalaya_ui_is_oracle_legacy', 0)
let s:himalayaui_icons = get(g:, 'himalaya_ui_icons', {})
let s:expanded_icon = get(s:himalayaui_icons, 'expanded', '▾')
let s:collapsed_icon = get(s:himalayaui_icons, 'collapsed', '▸')
let s:expanded_icons = {}
let s:collapsed_icons = {}

let g:himalaya_ui_eml_converter = get(g:, 'himalaya_ui_html_viewer', 'mhonarc')
let g:himalaya_ui_eml_converter_args = get(g:, 'himalaya_ui_eml_converter_args', '-single')
let g:himalaya_ui_html_viewer = get(g:, 'himalaya_ui_html_viewer', 'cha')
let g:himalaya_ui_html_viewer_args = get(g:, 'himalaya_ui_html_viewer_args', '--type "text/html" -c "body{background-color: transparent !important;}"')

if type(s:expanded_icon) !=? type('')
  let s:expanded_icons = s:expanded_icon
  let s:expanded_icon = '▾'
else
  silent! call remove(s:himalayaui_icons, 'expanded')
endif

if type(s:collapsed_icon) !=? type('')
  let s:collapsed_icons = s:collapsed_icon
  let s:collapsed_icon = '▸'
else
  silent! call remove(s:himalayaui_icons, 'collapsed')
endif

let g:himalaya_ui_icons = {
      \ 'expanded': {
      \   'himalaya': s:expanded_icon,
      \   'buffers': s:expanded_icon,
      \   'saved_queries': s:expanded_icon,
      \   'schemas': s:expanded_icon,
      \   'schema': s:expanded_icon,
      \   'folders': s:expanded_icon,
      \   'tables': s:expanded_icon,
      \   'table': s:expanded_icon,
      \ },
      \ 'collapsed': {
      \   'himalaya': s:collapsed_icon,
      \   'buffers': s:collapsed_icon,
      \   'saved_queries': s:collapsed_icon,
      \   'schemas': s:collapsed_icon,
      \   'schema': s:collapsed_icon,
      \   'folders': s:collapsed_icon,
      \   'tables': s:collapsed_icon,
      \   'table': s:collapsed_icon,
      \ },
      \ 'saved_list': '*',
      \ 'new_list': '+',
      \ 'folders': '~',
      \ 'tables': '~',
      \ 'buffers': '»',
      \ 'add_connection': '[+]',
      \ 'connection_ok': '✓',
      \ 'connection_error': '✕',
      \ }

if g:himalaya_ui_use_nerd_fonts
  let g:himalaya_ui_icons = {
        \ 'expanded': {
        \   'himalaya': s:expanded_icon.' 󰆼',
        \   'buffers': s:expanded_icon.' ',
        \   'saved_queries': s:expanded_icon.' ',
        \   'schemas': s:expanded_icon.' ',
        \   'schema': s:expanded_icon.' 󰙅',
        \   'folders': s:expanded_icon.' ',
        \   'tables': s:expanded_icon.' 󰓱',
        \   'table': s:expanded_icon.' ',
        \ },
        \ 'collapsed': {
        \   'himalaya': s:collapsed_icon.' 󰆼',
        \   'buffers': s:collapsed_icon.' ',
        \   'saved_queries': s:collapsed_icon.' ',
        \   'schemas': s:collapsed_icon.' ',
        \   'schema': s:collapsed_icon.' 󰙅',
        \   'folders': s:expanded_icon.' ',
        \   'tables': s:collapsed_icon.' 󰓱',
        \   'table': s:collapsed_icon.' ',
        \ },
        \ 'saved_list': '  ',
        \ 'new_list': '  󰓰',
        \ 'tables': '  󰓫',
        \ 'folders': '  ',
        \ 'buffers': '  ',
        \ 'add_connection': '  󰆺',
        \ 'connection_ok': '✓',
        \ 'connection_error': '✕',
        \ }
endif

let g:himalaya_ui_icons.expanded = extend(g:himalaya_ui_icons.expanded, s:expanded_icons)
let g:himalaya_ui_icons.collapsed = extend(g:himalaya_ui_icons.collapsed, s:collapsed_icons)
silent! call remove(s:himalayaui_icons, 'expanded')
silent! call remove(s:himalayaui_icons, 'collapsed')
let g:himalaya_ui_icons = extend(g:himalaya_ui_icons, s:himalayaui_icons)

augroup himalayaui
  autocmd!
  autocmd BufRead,BufNewFile *.himalayaout set filetype=himalayaout
  autocmd BufReadPost *.himalayaout nested call himalaya_ui#save_himalayaout(expand('<afile>'))
  autocmd FileType himalayaout setlocal foldmethod=expr foldexpr=himalaya_ui#himalayaout#foldexpr(v:lnum) | silent! normal!zo
  autocmd FileType himalayaout,himalayaui autocmd BufEnter,WinEnter <buffer> stopinsert
augroup END

command! HIMALAYAUI call himalaya_ui#open('<mods>')
command! HIMALAYAToggle call himalaya_ui#toggle()
command! HIMALAYAUIClose call himalaya_ui#close()
command! HIMALAYAUIAddConnection call himalaya_ui#connections#add()
command! HIMALAYAUIFindBuffer call himalaya_ui#find_buffer()
command! HIMALAYAUIRenameBuffer call himalaya_ui#rename_buffer()
command! HIMALAYAUILastQueryInfo call himalaya_ui#print_last_list_info()
