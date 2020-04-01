let s:query_instance = {}
let s:query = {}

function! db_ui#query#new(drawer) abort
  let s:query_instance = s:query.new(a:drawer)
  return s:query_instance
endfunction

function! s:query.new(drawer) abort
  let instance = copy(self)
  let instance.drawer = a:drawer
  let instance.buffer_counter = {}
  return instance
endfunction

function! s:query.open(item, edit_action) abort
  let db = self.drawer.dbui.dbs[a:item.db_key_name]
  if a:item.type ==? 'buffer'
    return self.open_buffer(db, a:item.file_path, a:edit_action)
  endif
  let suffix = 'query'
  let table = ''
  if a:item.type !=? 'query'
    let suffix = a:item.table.'-'.a:item.label
    let table = a:item.table
  endif

  let buffer_name = printf('%s.%s', tempname(), self.generate_buffer_basename(db.name, suffix))
  call self.open_buffer(db, buffer_name, a:edit_action, table, get(a:item, 'content'))
  nnoremap <buffer><silent><Plug>(DBUI_SaveQuery) :call <sid>method('save_query')<CR>
endfunction

function! s:method(name) abort
  return s:query[a:name]()
endfunction

function! s:query.generate_buffer_basename(db_name, suffix) abort
  let buffer_basename = substitute(printf('%s-%s', a:db_name, a:suffix), '[^A-Za-z0-9_\-]', '', 'g')
  if !has_key(self.buffer_counter, buffer_basename)
    let self.buffer_counter[buffer_basename] = 1
    return buffer_basename
  endif

  let new_name = buffer_basename.'-'.self.buffer_counter[buffer_basename]
  let self.buffer_counter[buffer_basename] += 1
  return new_name
endfunction

function! s:query.focus_window() abort
  if winnr('$') ==? 1
    vertical new
    return
  endif

  let found = 0
  for win in range(1, winnr('$'))
    let buf = winbufnr(win)
    if !empty(getbufvar(buf, 'db_ui_database'))
      let found = 1
      exe win.'wincmd w'
      break
    endif
  endfor

  if !found
    2wincmd w
  endif
endfunction

function s:query.open_buffer(db, buffer_name, edit_action, ...)
  let table = get(a:, 1, '')
  let default_content = get(a:, 2, g:dbui_default_query)
  let was_single_win = winnr('$') ==? 1
  if a:edit_action ==? 'edit'
    call self.focus_window()
    let bufnr = bufnr(a:buffer_name)
    if bufnr > -1
      call self.focus_window()
      silent! exe 'b '.bufnr
      setlocal filetype=sql nolist noswapfile nowrap cursorline nospell modifiable
      nnoremap <buffer><silent><Plug>(DBUI_EditBindParameters) :call <sid>method('edit_bind_parameters')<CR>
      call self.resize_if_single(was_single_win)
      return
    endif
  endif

  silent! exe a:edit_action.' '.a:buffer_name
  call self.resize_if_single(was_single_win)
  let b:db_key_name = a:db.key_name
  let b:db_ui_database = {'name': a:db.name, 'key_name': a:db.key_name, 'url': a:db.url, 'save_path': a:db.save_path }
  let db_buffers = self.drawer.dbui.dbs[a:db.key_name].buffers

  if index(db_buffers.list, a:buffer_name) ==? -1
    if empty(db_buffers.list)
      let db_buffers.expanded = 1
    endif
    call add(db_buffers.list, a:buffer_name)
  endif
  setlocal filetype=sql nolist noswapfile nowrap cursorline nospell modifiable
  nnoremap <buffer><Plug>(DBUI_EditBindParameters) :call <sid>method('edit_bind_parameters')<CR>
  augroup db_ui_query
    autocmd! * <buffer>
    autocmd BufWritePost <buffer> nested call s:method('execute_query')
    autocmd BufDelete,BufWipeout <buffer> silent! call s:method('remove_buffer', str2nr(expand('<abuf>')))
  augroup END

  if empty(table)
    return
  endif

  let content = substitute(default_content, '{table}', table, 'g')
  let content = substitute(content, '{dbname}', a:db.name, 'g')
  silent 1,$delete _
  call setline(1, split(content, "\n"))
  if g:dbui_auto_execute_table_helpers
    write
  endif
endfunction

function! s:method(name, ...) abort
  if a:0 > 0
    return s:query_instance[a:name](a:1)
  endif

  return s:query_instance[a:name]()
endfunction

function! s:query.resize_if_single(is_single_win) abort
  if a:is_single_win
    exe bufwinnr('dbui').'wincmd w'
    exe 'vertical resize '.g:dbui_winwidth
    wincmd p
  endif
endfunction

function! s:query.remove_buffer(bufnr)
  let db_key_name = getbufvar(a:bufnr, 'db_key_name')
  let list = self.drawer.dbui.dbs[db_key_name].buffers.list
  return filter(list, 'v:val !=? bufname(a:bufnr)')
endfunction

function! s:query.execute_query() abort
  let query_time = reltime()
  call db_ui#utils#echo_msg('Executing query...')
  let db = self.drawer.dbui.dbs[b:db_key_name]
  if search(':\w\+', 'n') > 0
    call self.inject_variables_and_execute(db)
  else
    silent! exe '%DB '.db.url
  endif
  call db_ui#utils#echo_msg('Executing query...Done after '.split(reltimestr(reltime(query_time)))[0].' sec.')
endfunction

function! s:query.inject_variables_and_execute(db) abort
  let vars = []
  for line in getline(1, '$')
    call substitute(line, '\(:\w\+\)', '\=add(vars, submatch(0))', 'g')
  endfor

  if !exists('b:db_ui_bind_params')
    let b:db_ui_bind_params = {}
  endif

  let existing_vars = keys(b:db_ui_bind_params)
  let needs_prompt = !empty(filter(copy(vars), 'index(existing_vars, v:val) <= -1'))
  if needs_prompt
    echo "Please provide bind parameters. Empty values are ignored and considered a raw value.\n\n"
  endif

  for var in vars
    if !has_key(b:db_ui_bind_params, var)
      let b:db_ui_bind_params[var] = db_ui#utils#input('Enter value for bind parameter '.var.' -> ', '')
    endif
  endfor

  let content = join(getline(1, '$'))

  for [var, val] in items(b:db_ui_bind_params)
    if trim(val) ==? ''
      continue
    endif

    if val !=? "^'.*'$" && (val =~? '^[0-9]*$' || val =~? '^\(true\|false\)$' || val =~? "''")
      let content = substitute(content, var, val, 'g')
    else
      let content = substitute(content, var, "'".val."'", 'g')
    endif
  endfor

  exe 'DB '.a:db.url.' '.content
  call db_ui#utils#echo_msg('Executing query...Done.')
endfunction

function! s:query.edit_bind_parameters() abort
  if !exists('b:db_ui_bind_params') || empty(b:db_ui_bind_params)
    return db_ui#utils#echo_msg('No bind parameters to edit.')
  endif

  let variable_names = keys(b:db_ui_bind_params)
  let opts = ['Select bind parameter to edit/delete:'] + map(copy(variable_names), '(v:key + 1).") ".v:val." (".(trim(b:db_ui_bind_params[v:val]) ==? "" ? "Not provided" : b:db_ui_bind_params[v:val]).")"')
  let selection = db_ui#utils#inputlist(opts)

  if selection < 1 || selection > len(variable_names)
    return db_ui#utils#echo_err('Wrong selection.')
  endif

  let var_name = variable_names[selection - 1]
  let variable = b:db_ui_bind_params[var_name]
  redraw!
  let action = confirm('Select action for '.var_name.'? ', "&Edit\n&Delete\n&Cancel")
  if action ==? 1
    redraw!
    let b:db_ui_bind_params[var_name] = db_ui#utils#input('Enter new value: ', variable)
    return db_ui#utils#echo_msg('Changed.')
  endif

  if action ==? 2
    unlet b:db_ui_bind_params[var_name]
    return db_ui#utils#echo_msg('Deleted.')
  endif

  return db_ui#utils#echo_msg('Canceled')
endfunction

function! s:query.save_query() abort
  let db = self.drawer.dbui.dbs[b:db_key_name]
  if empty(db.save_path)
    throw 'Save location is empty. Please provide valid directory to g:db_ui_save_location'
  endif

  if !isdirectory(db.save_path)
    call mkdir(db.save_path, 'p')
  endif

  let name = db_ui#utils#input('Save as: ', '')

  let full_name = printf('%s/%s', db.save_path, name)
  if filereadable(full_name)
    throw 'That file already exists. Please choose another name.'
  endif

  exe 'write '.full_name
  call self.drawer.load_saved_queries(db)
endfunction
