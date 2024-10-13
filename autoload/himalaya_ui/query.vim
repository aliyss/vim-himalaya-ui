let s:query_instance = {}
let s:query = {}
let s:bind_param_rgx = '\(^\|[[:blank:]]\|[^:]\)\('.g:himalaya_ui_bind_param_pattern.'\)'

let s:query_info = {
      \ 'last_query_start_time': 0,
      \ 'last_query_time': 0
      \ }

function! himalaya_ui#query#new(drawer) abort
  let s:query_instance = s:query.new(a:drawer)
  return s:query_instance
endfunction

function! s:query.new(drawer) abort
  let instance = copy(self)
  let instance.drawer = a:drawer
  let instance.buffer_counter = {}
  let instance.last_query = []
  augroup himalayaui_async_queries
    autocmd!
    autocmd User *HIMALAYAExecutePre call s:start_query()
    autocmd User *HIMALAYAExecutePost call s:print_query_time()
  augroup END
  return instance
endfunction

function! s:query.open(item, edit_action) abort
  let himalaya = self.drawer.himalayaui.himalayas[a:item.himalayaui_himalaya_key_name]
  if a:item.type ==? 'buffer'
    return self.open_buffer(himalaya, a:item.file_path, a:edit_action)
  endif
  let label = get(a:item, 'label', '')
  let table = ''
  let schema = ''
  if a:item.type !=? 'query'
    let suffix = a:item.table.'-'.a:item.label
    let table = a:item.table
    let schema = a:item.schema
  endif

  let buffer_name = self.generate_buffer_name(himalaya, { 'schema': schema, 'table': table, 'label': label, 'filetype': himalaya.filetype })
  call self.open_buffer(himalaya, buffer_name, a:edit_action, {'table': table, 'content': get(a:item, 'content'), 'schema': schema })
endfunction

function! s:query.generate_buffer_name(himalaya, opts) abort
  let time = exists('*strftime') ? strftime('%Y-%m-%d-%H-%M-%S') : localtime()
  let suffix = 'query'
  if !empty(a:opts.table)
    let suffix = printf('%s-%s', a:opts.table, a:opts.label)
  endif

  let buffer_name = himalaya_ui#utils#slug(printf('%s-%s', a:himalaya.name, suffix))
  let buffer_name = printf('%s-%s', buffer_name, time)
  if type(g:Db_ui_buffer_name_generator) ==? type(function('tr'))
    let buffer_name = printf('%s-%s', a:himalaya.name, call(g:Db_ui_buffer_name_generator, [a:opts]))
  endif

  if !empty(self.drawer.himalayaui.tmp_location)
    return printf('%s/%s', self.drawer.himalayaui.tmp_location, buffer_name)
  endif

  let tmp_name = printf('%s/%s', fnamemodify(tempname(), ':p:h'), buffer_name)
  call add(a:himalaya.buffers.tmp, tmp_name)
  return tmp_name
endfunction

function! s:query.focus_window() abort
  let win_pos = g:himalaya_ui_win_position ==? 'left' ? 'botright' : 'topleft'
  let win_cmd = 'vertical '.win_pos.' new'
  if winnr('$') ==? 1
    silent! exe win_cmd
    return
  endif

  let found = 0
  for win in range(1, winnr('$'))
    let buf = winbufnr(win)
    if !empty(getbufvar(buf, 'himalayaui_himalaya_key_name'))
      let found = 1
      exe win.'wincmd w'
      break
    endif
  endfor

  if !found
    for win in range(1, winnr('$'))
      if getwinvar(win, '&filetype') !=? 'himalayaui' && getwinvar(win, '&buftype') !=? 'nofile' && getwinvar(win, '&modifiable')
        let found = 1
        exe win.'wincmd w'
        break
      endif
    endfor
  endif

  if (!found)
    silent! exe win_cmd
  endif
endfunction

function s:query.open_buffer(himalaya, buffer_name, edit_action, ...)
  let opts = get(a:, '1', {})
  let table = get(opts, 'table', '')
  let schema = get(opts, 'schema', '')
  let default_content = get(opts, 'content', g:himalaya_ui_default_query)
  let was_single_win = winnr('$') ==? 1

  if a:edit_action ==? 'edit'
    call self.focus_window()
    let bufnr = bufnr(a:buffer_name)
    if bufnr > -1
      silent! exe 'b '.bufnr
      call self.setup_buffer(a:himalaya, extend({'existing_buffer': 1 }, opts), a:buffer_name, was_single_win)
      return
    endif
  endif

  silent! exe a:edit_action.' '.a:buffer_name
  call self.setup_buffer(a:himalaya, opts, a:buffer_name, was_single_win)

  if empty(table)
    return
  endif

  let optional_schema = schema ==? a:himalaya.default_scheme ? '' : schema

  if !empty(optional_schema)
    if a:himalaya.quote
      let optional_schema = '"'.optional_schema.'"'
    endif
    let optional_schema = optional_schema.'.'
  endif

  let content = substitute(default_content, '{table}', table, 'g')
  let content = substitute(content, '{optional_schema}', optional_schema, 'g')
  let content = substitute(content, '{schema}', schema, 'g')
  let himalaya_name = !empty(schema) ? schema : a:himalaya.himalaya_name
  let content = substitute(content, '{himalayaname}', himalaya_name, 'g')
  let content = substitute(content, '{last_query}', join(self.last_query, "\n"), 'g')
  silent 1,$delete _
  call setline(1, split(content, "\n"))
  if g:himalaya_ui_auto_execute_table_helpers
    if g:himalaya_ui_execute_on_save
      write
    else
      call self.execute_query()
    endif
  endif
endfunction

function! s:query.setup_buffer(himalaya, opts, buffer_name, was_single_win) abort
  call self.resize_if_single(a:was_single_win)
  let b:himalayaui_himalaya_key_name = a:himalaya.key_name
  let b:himalayaui_table_name = get(a:opts, 'table', '')
  let b:himalayaui_schema_name = get(a:opts, 'schema', '')
  let b:himalaya = a:himalaya.conn
  let is_existing_buffer = get(a:opts, 'existing_buffer', 0)
  let is_tmp = self.drawer.himalayaui.is_tmp_location_buffer(a:himalaya, a:buffer_name)
  let himalaya_buffers = self.drawer.himalayaui.himalayas[a:himalaya.key_name].buffers

  if index(himalaya_buffers.list, a:buffer_name) ==? -1
    if empty(himalaya_buffers.list)
      let himalaya_buffers.expanded = 1
    endif
    call add(himalaya_buffers.list, a:buffer_name)
    call self.drawer.render()
  endif

  if &filetype !=? a:himalaya.filetype || !is_existing_buffer
    silent! exe 'setlocal filetype='.a:himalaya.filetype.' nolist noswapfile nowrap nospell modifiable'
  endif
  let is_sql = &filetype ==? a:himalaya.filetype
  nnoremap <silent><buffer><Plug>(HIMALAYAUI_EditBindParameters) :call <sid>method('edit_bind_parameters')<CR>
  nnoremap <silent><buffer><Plug>(HIMALAYAUI_ExecuteQuery) :call <sid>method('execute_query')<CR>
  vnoremap <silent><buffer><Plug>(HIMALAYAUI_ExecuteQuery) :<C-u>call <sid>method('execute_query', 1)<CR>
  if is_tmp && is_sql
    nnoremap <silent><buffer><silent><Plug>(HIMALAYAUI_SaveQuery) :call <sid>method('save_query')<CR>
  endif
  augroup himalaya_ui_query
    autocmd! * <buffer>
    if g:himalaya_ui_execute_on_save && is_sql
      autocmd BufWritePost <buffer> nested call s:method('execute_query')
    endif
    autocmd BufDelete,BufWipeout <buffer> silent! call s:method('remove_buffer', str2nr(expand('<abuf>')))
  augroup END
endfunction

function! s:method(name, ...) abort
  if a:0 > 0
    return s:query_instance[a:name](a:1)
  endif

  return s:query_instance[a:name]()
endfunction

function! s:query.resize_if_single(is_single_win) abort
  if a:is_single_win
    exe self.drawer.get_winnr().'wincmd w'
    exe 'vertical resize '.g:himalaya_ui_winwidth
    wincmd p
  endif
endfunction

function! s:query.remove_buffer(bufnr)
  let himalayaui_himalaya_key_name = getbufvar(a:bufnr, 'himalayaui_himalaya_key_name')
  let list = self.drawer.himalayaui.himalayas[himalayaui_himalaya_key_name].buffers.list
  let tmp = self.drawer.himalayaui.himalayas[himalayaui_himalaya_key_name].buffers.tmp
  call filter(list, 'v:val !=? bufname(a:bufnr)')
  call filter(tmp, 'v:val !=? bufname(a:bufnr)')
  return self.drawer.render()
endfunction

function! s:query.execute_query(...) abort
  let is_visual_mode = get(a:, 1, 0)
  let lines = self.get_lines(is_visual_mode)
  call s:start_query()
  if !is_visual_mode && search(s:bind_param_rgx, 'n') <= 0
    call himalaya_ui#utils#print_debug({ 'message': 'Executing whole buffer', 'command': '%HIMALAYA' })
    silent! exe '%HIMALAYA'
  else
    let himalaya = self.drawer.himalayaui.himalayas[b:himalayaui_himalaya_key_name]
    call self.execute_lines(himalaya, lines, is_visual_mode)
  endif
  let has_async = exists('*himalaya#cancel')
  if has_async
    call himalaya_ui#notifications#info('Executing query...')
  endif
  if !has_async
    call s:print_query_time()
  endif
  let self.last_query = lines
endfunction

function! s:query.execute_lines(himalaya, lines, is_visual_mode) abort
  let filename = tempname().'.'.himalaya#adapter#call(a:himalaya.conn, 'input_extension', [], 'sql')
  let lines = copy(a:lines)
  let should_inject_vars = match(join(a:lines), s:bind_param_rgx) > -1

  if should_inject_vars
    try
      let lines = self.inject_variables(lines)
    catch /.*/
      return himalaya_ui#notifications#error(v:exception)
    endtry
  endif

  if len(lines) ==? 1
  call himalaya_ui#utils#print_debug({'message': 'Executing single line', 'line': lines[0], 'command': 'HIMALAYA '.lines[0] })
    exe 'HIMALAYA '.lines[0]
    return lines
  endif

  if empty(should_inject_vars)
    call himalaya_ui#utils#print_debug({'message': 'Executing visual selection', 'command': "'<,'>HIMALAYA"})
    exe "'<,'>HIMALAYA"
  else
    call himalaya_ui#utils#print_debug({'message': 'Executing multiple lines', 'lines': lines, 'input_filename': filename, 'command': 'HIMALAYA < '.filename })
    call writefile(lines, filename)
    exe 'HIMALAYA < '.filename
  endif

  return lines
endfunction

function! s:query.get_lines(is_visual_mode) abort
  if !a:is_visual_mode
    return getline(1, '$')
  endif

  let sel_save = &selection
  let &selection = 'inclusive'
  let reg_save = @@
  silent exe 'normal! gvy'
  let lines = split(@@, "\n")
  let &selection = sel_save
  let @@ = reg_save
  return lines
endfunction

function! s:query.inject_variables(lines) abort
  let vars = []
  for line in a:lines
    call substitute(line, s:bind_param_rgx, '\=add(vars, submatch(2))', 'g')
  endfor

  call filter(vars, {i,var -> !search(printf("'[^']*%s[^']*'", var), 'n')})

  if !exists('b:himalayaui_bind_params')
    let b:himalayaui_bind_params = {}
  endif

  let existing_vars = keys(b:himalayaui_bind_params)
  let needs_prompt = !empty(filter(copy(vars), 'index(existing_vars, v:val) <= -1'))
  if needs_prompt
    echo "Please provide bind parameters. Empty values are ignored and considered a raw value.\n\n"
  endif

  let bind_params = copy(b:himalayaui_bind_params)
  for var in vars
    if !has_key(bind_params, var)
      let bind_params[var] = himalaya_ui#utils#input('Enter value for bind parameter '.var.' -> ', '')
    endif
  endfor

  let b:himalayaui_bind_params = bind_params
  let content = []

  for line in a:lines
    for [var, val] in items(b:himalayaui_bind_params)
      if trim(val) ==? ''
        continue
      endif
      let line = substitute(line, var, himalaya_ui#utils#quote_query_value(val), 'g')
    endfor
    call add(content, line)
  endfor

  return content
endfunction

function! s:query.edit_bind_parameters() abort
  if !exists('b:himalayaui_bind_params') || empty(b:himalayaui_bind_params)
    return himalaya_ui#notifications#info('No bind parameters to edit.')
  endif

  let variable_names = keys(b:himalayaui_bind_params)
  if len(variable_names) > 1
    let opts = ['Select bind parameter to edit/delete:'] + map(copy(variable_names), '(v:key + 1).") ".v:val." (".(trim(b:himalayaui_bind_params[v:val]) ==? "" ? "Not provided" : b:himalayaui_bind_params[v:val]).")"')
    let selection = himalaya_ui#utils#inputlist(opts)

    if selection < 1 || selection > len(variable_names)
      return himalaya_ui#notifications#error('Wrong selection.')
    endif

    let var_name = variable_names[selection - 1]
    let variable = b:himalayaui_bind_params[var_name]
  else
    let var_name = variable_names[0]
    let variable = b:himalayaui_bind_params[var_name]
  endif
  redraw!
  let action = confirm('Select action for '.var_name.' param? ', "&Edit\n&Delete\n&Cancel")
  if action ==? 1
    redraw!
    try
      let b:himalayaui_bind_params[var_name] = himalaya_ui#utils#input('Enter new value: ', variable)
    catch /.*/
      return himalaya_ui#notifications#error(v:exception)
    endtry
    return himalaya_ui#notifications#info('Changed.')
  endif

  if action ==? 2
    unlet b:himalayaui_bind_params[var_name]
    return himalaya_ui#notifications#info('Deleted.')
  endif

  return himalaya_ui#notifications#info('Canceled')
endfunction

function! s:query.save_query() abort
  try
    let himalaya = self.drawer.himalayaui.himalayas[b:himalayaui_himalaya_key_name]
    if empty(himalaya.save_path)
      throw 'Save location is empty. Please provide valid directory to g:himalaya_ui_save_location'
    endif

    if !isdirectory(himalaya.save_path)
      call mkdir(himalaya.save_path, 'p')
    endif

    try
      let name = himalaya_ui#utils#input('Save as: ', '')
    catch /.*/
      return himalaya_ui#notifications#error(v:exception)
    endtry

    if empty(trim(name))
      throw 'No valid name provided.'
    endif

    let full_name = printf('%s/%s', himalaya.save_path, name)

    if filereadable(full_name)
      throw 'That file already exists. Please choose another name.'
    endif

    exe 'write '.full_name
    call self.drawer.render({ 'queries': 1 })
    call self.open_buffer(himalaya, full_name, 'edit')
  catch /.*/
    return himalaya_ui#notifications#error(v:exception)
  endtry
endfunction

function! s:query.get_last_query_info() abort
  return {
        \ 'last_query': self.last_query,
        \ 'last_query_time': s:query_info.last_query_time
        \ }
endfunction

function! s:query.get_saved_query_himalaya_name() abort
  let himalayaui = self.drawer.himalayaui
  if !empty(himalayaui.tmp_location) && himalayaui.tmp_location ==? expand('%:p:h')
    let filename = expand('%:t')
    if fnamemodify(filename, ':r') ==? 'himalaya_ui'
      let filename = fnamemodify(filename, ':e')
    endif
    let himalaya = get(filter(copy(himalayaui.himalayas_list), 'filename =~? "^".v:val.name."-"'), 0, {})
    if !empty(himalaya)
      return himalaya.name
    endif
  endif
  if expand('%:p:h:h') ==? himalayaui.save_path
    return expand('%:p:h:t')
  endif

  return ''
endfunction

function s:start_query() abort
  let s:query_info.last_query_start_time = reltime()
endfunction

function s:print_query_time() abort
  if empty(s:query_info.last_query_start_time)
    return
  endif
  let s:query_info.last_query_time = split(reltimestr(reltime(s:query_info.last_query_start_time)))[0]
  call himalaya_ui#notifications#info('Done after '.s:query_info.last_query_time.' sec.')
endfunction
