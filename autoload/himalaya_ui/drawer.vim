let s:drawer_instance = {}
let s:drawer = {}

function himalaya_ui#drawer#new(himalayaui)
  let s:drawer_instance = s:drawer.new(a:himalayaui)
  return s:drawer_instance
endfunction

function himalaya_ui#drawer#get()
  return s:drawer_instance
endfunction

function! s:drawer.new(himalayaui) abort
  let instance = copy(self)
  let instance.himalayaui = a:himalayaui
  let instance.show_details = 0
  let instance.show_help = 0
  let instance.show_himalayaout_list = 0
  let instance.content = []
  let instance.query = {}
  let instance.connections = {}

  return instance
endfunction

function! s:drawer.open(...) abort
  if self.is_opened()
    silent! exe self.get_winnr().'wincmd w'
    return
  endif
  let mods = get(a:, 1, '')
  if !empty(mods)
    silent! exe mods.' new himalayaui'
  else
    let win_pos = g:himalaya_ui_win_position ==? 'left' ? 'topleft' : 'botright'
    silent! exe 'vertical '.win_pos.' new himalayaui'
    silent! exe 'vertical '.win_pos.' resize '.g:himalaya_ui_winwidth
  endif
  setlocal filetype=himalayaui buftype=nofile bufhidden=wipe nobuflisted nolist noswapfile nowrap nospell nomodifiable winfixwidth nonumber norelativenumber signcolumn=no

  call self.render()
  nnoremap <silent><buffer> <Plug>(HIMALAYAUI_SelectLine) :call <sid>method('toggle_line', 'edit')<CR>
  nnoremap <silent><buffer> <Plug>(HIMALAYAUI_DeleteLine) :call <sid>method('delete_line')<CR>
  let query_win_pos = g:himalaya_ui_win_position ==? 'left' ? 'botright' : 'topleft'
  silent! exe "nnoremap <silent><buffer> <Plug>(HIMALAYAUI_SelectLineVsplit) :call <sid>method('toggle_line', 'vertical ".query_win_pos." split')<CR>"
  nnoremap <silent><buffer> <Plug>(HIMALAYAUI_Redraw) :call <sid>method('redraw')<CR>
  nnoremap <silent><buffer> <Plug>(HIMALAYAUI_AddConnection) :call <sid>method('add_connection')<CR>
  nnoremap <silent><buffer> <Plug>(HIMALAYAUI_ToggleDetails) :call <sid>method('toggle_details')<CR>
  nnoremap <silent><buffer> <Plug>(HIMALAYAUI_RenameLine) :call <sid>method('rename_line')<CR>
  nnoremap <silent><buffer> <Plug>(HIMALAYAUI_Quit) :call <sid>method('quit')<CR>

  nnoremap <silent><buffer> <Plug>(HIMALAYAUI_GotoFirstSibling) :call <sid>method('goto_sibling', 'first')<CR>
  nnoremap <silent><buffer> <Plug>(HIMALAYAUI_GotoNextSibling) :call <sid>method('goto_sibling', 'next')<CR>
  nnoremap <silent><buffer> <Plug>(HIMALAYAUI_GotoPrevSibling) :call <sid>method('goto_sibling', 'prev')<CR>
  nnoremap <silent><buffer> <Plug>(HIMALAYAUI_GotoLastSibling) :call <sid>method('goto_sibling', 'last')<CR>
  nnoremap <silent><buffer> <Plug>(HIMALAYAUI_GotoParentNode) :call <sid>method('goto_node', 'parent')<CR>
  nnoremap <silent><buffer> <Plug>(HIMALAYAUI_GotoChildNode) :call <sid>method('goto_node', 'child')<CR>

  nnoremap <silent><buffer> ? :call <sid>method('toggle_help')<CR>
  augroup himalaya_ui
    autocmd! * <buffer>
    autocmd BufEnter <buffer> call s:method('render')
  augroup END
  silent! doautocmd User HIMALAYAUIOpened
endfunction

function! s:drawer.is_opened() abort
  return self.get_winnr() > -1
endfunction

function! s:drawer.get_winnr() abort
  for nr in range(1, winnr('$'))
    if getwinvar(nr, '&filetype') ==? 'himalayaui'
      return nr
    endif
  endfor
  return -1
endfunction

function! s:drawer.redraw() abort
  let item = self.get_current_item()
  if item.level ==? 0
    return self.render({ 'himalayas': 1, 'queries': 1 })
  endif
  return self.render({'himalaya_key_name': item.himalayaui_himalaya_key_name, 'queries': 1 })
endfunction

function! s:drawer.toggle() abort
  if self.is_opened()
    return self.quit()
  endif
  return self.open()
endfunction

function! s:drawer.quit() abort
  if self.is_opened()
    silent! exe 'bd'.winbufnr(self.get_winnr())
  endif
endfunction

function! s:method(method_name, ...) abort
  if a:0 > 0
    return s:drawer_instance[a:method_name](a:1)
  endif

  return s:drawer_instance[a:method_name]()
endfunction

function! s:drawer.goto_sibling(direction)
  let index = line('.') - 1
  let last_index = len(self.content) - 1
  let item = self.content[index]
  let current_level = item.level
  let is_up = a:direction ==? 'first' || a:direction ==? 'prev'
  let is_down = !is_up
  let is_edge = a:direction ==? 'first' || a:direction ==? 'last'
  let is_prev_or_next = !is_edge
  let last_index_same_level = index

  while ((is_up && index >= 0) || (is_down && index < last_index))
    let adjacent_index = is_up ? index - 1 : index + 1
    let is_on_edge = (is_up && adjacent_index ==? 0) || (is_down && adjacent_index ==? last_index)
    let adjacent_item = self.content[adjacent_index]
    if adjacent_item.level ==? 0 && adjacent_item.label ==? ''
      return cursor(index + 1, col('.'))
    endif

    if is_prev_or_next
      if adjacent_item.level ==? current_level
        return cursor(adjacent_index + 1, col('.'))
      endif
      if adjacent_item.level < current_level
        return
      endif
    endif

    if is_edge
      if adjacent_item.level ==? current_level
        let last_index_same_level = adjacent_index
      endif
      if adjacent_item.level < current_level || is_on_edge
        return cursor(last_index_same_level + 1, col('.'))
      endif
    endif
    let index = adjacent_index
  endwhile
endfunction

function! s:drawer.goto_node(direction)
  let index = line('.') - 1
  let item = self.content[index]
  let last_index = len(self.content) - 1
  let is_up = a:direction ==? 'parent'
  let is_down = !is_up
  let Is_correct_level = {adj-> a:direction ==? 'parent' ? adj.level ==? item.level - 1 : adj.level ==? item.level + 1}
  if is_up
    while index >= 0
      let index = index - 1
      let adjacent_item = self.content[index]
      if adjacent_item.level < item.level
        break
      endif
    endwhile
    return cursor(index + 1, col('.'))
  endif

  if item.action !=? 'toggle'
    return
  endif

  if !item.expanded
    call self.toggle_line('')
  endif
  norm! j
endfunction

function s:drawer.get_current_item() abort
  return self.content[line('.') - 1]
endfunction

function! s:drawer.rename_buffer(buffer, himalaya_key_name, is_saved_query) abort
  let bufnr = bufnr(a:buffer)
  let current_win = winnr()
  let current_ft = &filetype

  if !filereadable(a:buffer)
    return himalaya_ui#notifications#error('Only written queries can be renamed.')
  endif

  if empty(a:himalaya_key_name)
    return himalaya_ui#notifications#error('Buffer not attached to any database')
  endif

  let bufwin = bufwinnr(bufnr)
  let himalaya = self.himalayaui.himalayas[a:himalaya_key_name]
  let himalaya_slug = himalaya_ui#utils#slug(himalaya.name)
  let is_saved = a:is_saved_query || !self.himalayaui.is_tmp_location_buffer(himalaya, a:buffer)
  let old_name = self.get_buffer_name(himalaya, a:buffer)

  try
    let new_name = himalaya_ui#utils#input('Enter new name: ', old_name)
  catch /.*/
    return himalaya_ui#notifications#error(v:exception)
  endtry

  if empty(new_name)
    return himalaya_ui#notifications#error('Valid name must be provided.')
  endif

  if is_saved
    let new = printf('%s/%s', fnamemodify(a:buffer, ':p:h'), new_name)
  else
    let new = printf('%s/%s', fnamemodify(a:buffer, ':p:h'), himalaya_slug.'-'.new_name)
    call add(himalaya.buffers.tmp, new)
  endif

  call rename(a:buffer, new)
  let new_bufnr = -1

  if bufwin > -1
    call self.get_query().open_buffer(himalaya, new, 'edit')
    let new_bufnr = bufnr('%')
  elseif bufnr > -1
    exe 'badd '.new
    let new_bufnr = bufnr(new)
    call add(himalaya.buffers.list, new)
  elseif index(himalaya.buffers.list, a:buffer) > -1
    call insert(himalaya.buffers.list, new, index(himalaya.buffers.list, a:buffer))
  endif

  call filter(himalaya.buffers.list, 'v:val !=? a:buffer')

  if new_bufnr > - 1
    call setbufvar(new_bufnr, 'himalayaui_himalaya_key_name', himalaya.key_name)
    call setbufvar(new_bufnr, 'himalaya', himalaya.conn)
    call setbufvar(new_bufnr, 'himalayaui_himalaya_table_name', getbufvar(a:buffer, 'himalayaui_himalaya_table_name'))
    call setbufvar(new_bufnr, 'himalayaui_bind_params', getbufvar(a:buffer, 'himalayaui_bind_params'))
  endif

  silent! exe 'bw! '.a:buffer
  if winnr() !=? current_win
    wincmd p
  endif

  return self.render({ 'queries': 1 })
endfunction

function! s:drawer.rename_line() abort
  let item = self.get_current_item()
  if item.type ==? 'buffer'
    return self.rename_buffer(item.file_path, item.himalayaui_himalaya_key_name, get(item, 'saved', 0))
  endif

  if item.type ==? 'himalaya'
    return self.get_connections().rename(self.himalayaui.himalayas[item.himalayaui_himalaya_key_name])
  endif

  return
endfunction

function! s:drawer.add_connection() abort
  return self.get_connections().add()
endfunction

function! s:drawer.toggle_himalayaout_queries() abort
  let self.show_himalayaout_list = !self.show_himalayaout_list
  return self.render()
endfunction

function! s:drawer.delete_connection(himalaya) abort
  return self.get_connections().delete(a:himalaya)
endfunction

function! s:drawer.get_connections() abort
  if empty(self.connections)
    let self.connections = himalaya_ui#connections#new(self)
  endif

  return self.connections
endfunction

function! s:drawer.toggle_help() abort
  let self.show_help = !self.show_help
  return self.render()
endfunction

function! s:drawer.toggle_details() abort
  let self.show_details = !self.show_details
  return self.render()
endfunction

function! s:drawer.focus() abort
  if &filetype ==? 'himalayaui'
    return 0
  endif

  let winnr = self.get_winnr()
  if winnr > -1
    exe winnr.'wincmd w'
    return 1
  endif
  return 0
endfunction

function! s:drawer.render(...) abort
  let opts = get(a:, 1, {})
  let restore_win = self.focus()

  if &filetype !=? 'himalayaui'
    return
  endif

  if get(opts, 'himalayas', 0)
    let query_time = reltime()
    call himalaya_ui#notifications#info('Refreshing all databases...')
    call self.himalayaui.populate_himalayas()
    call himalaya_ui#notifications#info('Refreshed all databases after '.split(reltimestr(reltime(query_time)))[0].' sec.')
  endif

  if !empty(get(opts, 'himalaya_key_name', ''))
    let himalaya = self.himalayaui.himalayas[opts.himalaya_key_name]
    call himalaya_ui#notifications#info('Refreshing database '.himalaya.name.'...')
    let query_time = reltime()
    let self.himalayaui.himalayas[opts.himalaya_key_name] = self.populate(himalaya)
    call himalaya_ui#notifications#info('Refreshed database '.himalaya.name.' after '.split(reltimestr(reltime(query_time)))[0].' sec.')
  endif

  redraw!
  let view = winsaveview()
  let self.content = []

  call self.render_help()

  for himalaya in self.himalayaui.himalayas_list
    if get(opts, 'queries', 0)
      call self.load_saved_queries(self.himalayaui.himalayas[himalaya.key_name])
    endif
    call self.add_himalaya(self.himalayaui.himalayas[himalaya.key_name])
  endfor

  if empty(self.himalayaui.himalayas_list)
    call self.add('" No connections', 'noaction', 'help', '', '', 0)
    call self.add('Add connection', 'call_method', 'add_connection', g:himalaya_ui_icons.add_connection, '', 0)
  endif


  if !empty(self.himalayaui.himalayaout_list)
    call self.add('', 'noaction', 'help', '', '', 0)
    call self.add('Query results ('.len(self.himalayaui.himalayaout_list).')', 'call_method', 'toggle_himalayaout_queries', self.get_toggle_icon('saved_queries', {'expanded': self.show_himalayaout_list}), '', 0)

    if self.show_himalayaout_list
      let entries = sort(keys(self.himalayaui.himalayaout_list), function('s:sort_himalayaout'))
      for entry in entries
        let content = ''
        if !empty(self.himalayaui.himalayaout_list[entry])
          let content = printf(' (%s)', self.himalayaui.himalayaout_list[entry].content)
        endif
        call self.add(fnamemodify(entry, ':t').content, 'open', 'himalayaout', g:himalaya_ui_icons.tables, '', 1, { 'file_path': entry })
      endfor
    endif
  endif

  let content = map(copy(self.content), 'repeat(" ", shiftwidth() * v:val.level).v:val.icon.(!empty(v:val.icon) ? " " : "").v:val.label')

  setlocal modifiable
  silent 1,$delete _
  call setline(1, content)
  setlocal nomodifiable
  call winrestview(view)

  if restore_win
    wincmd p
  endif
endfunction

function! s:drawer.render_help() abort
  if g:himalaya_ui_show_help
    call self.add('" Press ? for help', 'noaction', 'help', '', '', 0)
    call self.add('', 'noaction', 'help', '', '', 0)
  endif

  if self.show_help
    call self.add('" o - Open/Toggle selected item', 'noaction', 'help', '', '', 0)
    call self.add('" S - Open/Toggle selected item in vertical split', 'noaction', 'help', '', '', 0)
    call self.add('" d - Delete selected item', 'noaction', 'help', '', '', 0)
    call self.add('" R - Redraw', 'noaction', 'help', '', '', 0)
    call self.add('" A - Add connection', 'noaction', 'help', '', '', 0)
    call self.add('" H - Toggle database details', 'noaction', 'help', '', '', 0)
    call self.add('" r - Rename/Edit buffer/connection/saved query', 'noaction', 'help', '', '', 0)
    call self.add('" q - Close drawer', 'noaction', 'help', '', '', 0)
    call self.add('" <C-j>/<C-k> - Go to last/first sibling', 'noaction', 'help', '', '', 0)
    call self.add('" K/J - Go to prev/next sibling', 'noaction', 'help', '', '', 0)
    call self.add('" <C-p>/<C-n> - Go to parent/child node', 'noaction', 'help', '', '', 0)
    call self.add('" <Leader>W - (sql) Save currently opened query', 'noaction', 'help', '', '', 0)
    call self.add('" <Leader>E - (sql) Edit bind parameters in opened query', 'noaction', 'help', '', '', 0)
    call self.add('" <Leader>S - (sql) Execute query in visual or normal mode', 'noaction', 'help', '', '', 0)
    call self.add('" <C-]> - (.himalayaout) Go to entry from foreign key cell', 'noaction', 'help', '', '', 0)
    call self.add('" <motion>ic - (.himalayaout) Operator pending mapping for cell value', 'noaction', 'help', '', '', 0)
    call self.add('" <Leader>R - (.himalayaout) Toggle expanded view', 'noaction', 'help', '', '', 0)
    call self.add('', 'noaction', 'help', '', '', 0)
  endif
endfunction

function! s:drawer.add(label, action, type, icon, himalayaui_himalaya_key_name, level, ...)
  let opts = extend({'label': a:label, 'action': a:action, 'type': a:type, 'icon': a:icon, 'himalayaui_himalaya_key_name': a:himalayaui_himalaya_key_name, 'level': a:level }, get(a:, '1', {}))
  call add(self.content, opts)
endfunction

function! s:drawer.add_himalaya(himalaya) abort
  let himalaya_name = a:himalaya.name
  if !empty(a:himalaya.conn_error)
    let himalaya_name .= ' '.g:himalaya_ui_icons.connection_error
  elseif !empty(a:himalaya.conn)
    let himalaya_name .= ' '.g:himalaya_ui_icons.connection_ok
  endif
  if self.show_details
    let himalaya_name .= ' ('.a:himalaya.backend.')'
  endif
  call self.add(himalaya_name, 'toggle', 'himalaya', self.get_toggle_icon('himalaya', a:himalaya), a:himalaya.key_name, 0, { 'expanded': a:himalaya.expanded })
  if !a:himalaya.expanded
    return a:himalaya
  endif

  call self.add('New query', 'open', 'query', g:himalaya_ui_icons.new_query, a:himalaya.key_name, 1)
  call self.add('Create E-Mail', 'open', 'email', g:himalaya_ui_icons.new_query, a:himalaya.key_name, 1)
  if !empty(a:himalaya.buffers.list)
    call self.add('Buffers ('.len(a:himalaya.buffers.list).')', 'toggle', 'buffers', self.get_toggle_icon('buffers', a:himalaya.buffers), a:himalaya.key_name, 1, { 'expanded': a:himalaya.buffers.expanded })
    if a:himalaya.buffers.expanded
      for buf in a:himalaya.buffers.list
        let buflabel = self.get_buffer_name(a:himalaya, buf)
        if self.himalayaui.is_tmp_location_buffer(a:himalaya, buf)
          let buflabel .= ' *'
        endif
        call self.add(buflabel, 'open', 'buffer', g:himalaya_ui_icons.buffers, a:himalaya.key_name, 2, { 'file_path': buf })
      endfor
    endif
  endif
  call self.add('Saved queries ('.len(a:himalaya.saved_queries.list).')', 'toggle', 'saved_queries', self.get_toggle_icon('saved_queries', a:himalaya.saved_queries), a:himalaya.key_name, 1, { 'expanded': a:himalaya.saved_queries.expanded })
  if a:himalaya.saved_queries.expanded
    for saved_query in a:himalaya.saved_queries.list
      call self.add(fnamemodify(saved_query, ':t'), 'open', 'buffer', g:himalaya_ui_icons.saved_query, a:himalaya.key_name, 2, { 'file_path': saved_query, 'saved': 1 })
    endfor
  endif

  if a:himalaya.schema_support
    call self.add('Schemas ('.len(a:himalaya.schemas.items).')', 'toggle', 'schemas', self.get_toggle_icon('schemas', a:himalaya.schemas), a:himalaya.key_name, 1, { 'expanded': a:himalaya.schemas.expanded })
    if a:himalaya.schemas.expanded
      for schema in a:himalaya.schemas.list
        let schema_item = a:himalaya.schemas.items[schema]
        let tables = schema_item.tables
        call self.add(schema.' ('.len(tables.items).')', 'toggle', 'schemas->items->'.schema, self.get_toggle_icon('schema', schema_item), a:himalaya.key_name, 2, { 'expanded': schema_item.expanded })
        if schema_item.expanded
          call self.render_tables(tables, a:himalaya,'schemas->items->'.schema.'->tables->items', 3, schema)
        endif
      endfor
    endif
  else
    call self.add('Tables ('.len(a:himalaya.tables.items).')', 'toggle', 'tables', self.get_toggle_icon('tables', a:himalaya.tables), a:himalaya.key_name, 1, { 'expanded': a:himalaya.tables.expanded })
    call self.render_tables(a:himalaya.tables, a:himalaya, 'tables->items', 2, '')
  endif
endfunction

function! s:drawer.render_tables(tables, himalaya, path, level, schema) abort
  if !a:tables.expanded
    return
  endif
  for table in a:tables.list
    call self.add(table, 'toggle', a:path.'->'.table, self.get_toggle_icon('table', a:tables.items[table]), a:himalaya.key_name, a:level, { 'expanded': a:tables.items[table].expanded })
    if a:tables.items[table].expanded
      for [helper_name, helper] in items(a:himalaya.table_helpers)
        call self.add(helper_name, 'open', 'table', g:himalaya_ui_icons.tables, a:himalaya.key_name, a:level + 1, {'table': table, 'content': helper, 'schema': a:schema })
      endfor
    endif
  endfor
endfunction

function! s:drawer.toggle_line(edit_action) abort
  let item = self.get_current_item()
  if item.action ==? 'noaction'
    return
  endif

  if item.action ==? 'call_method'
    return s:method(item.type)
  endif

  if item.type ==? 'himalayaout'
    call self.get_query().focus_window()
    silent! exe 'pedit' item.file_path
    return
  endif

  if item.action ==? 'open'
    return self.get_query().open(item, a:edit_action)
  endif

  let himalaya = self.himalayaui.himalayas[item.himalayaui_himalaya_key_name]

  let tree = himalaya
  if item.type !=? 'himalaya'
    let tree = self.get_nested(himalaya, item.type)
  endif

  let tree.expanded = !tree.expanded

  if item.type ==? 'himalaya'
    call self.toggle_himalaya(himalaya)
  endif

  return self.render()
endfunction

function! s:drawer.get_query() abort
  if empty(self.query)
    let self.query = himalaya_ui#query#new(self)
  endif
  return self.query
endfunction

function! s:drawer.delete_line() abort
  let item = self.get_current_item()

  if item.action ==? 'noaction'
    return
  endif

  if item.action ==? 'toggle' && item.type ==? 'himalaya'
    let himalaya = self.himalayaui.himalayas[item.himalayaui_himalaya_key_name]
    if himalaya.source !=? 'file'
      return himalaya_ui#notifications#error('Cannot delete this connection.')
    endif
    return self.delete_connection(himalaya)
  endif

  if item.action !=? 'open' || item.type !=? 'buffer'
    return
  endif

  let himalaya = self.himalayaui.himalayas[item.himalayaui_himalaya_key_name]

  if has_key(item, 'saved')
    let choice = confirm('Are you sure you want to delete this saved query?', "&Yes\n&No")
    if choice !=? 1
      return
    endif

    call delete(item.file_path)
    call remove(himalaya.saved_queries.list, index(himalaya.saved_queries.list, item.file_path))
    call filter(himalaya.buffers.list, 'v:val !=? item.file_path')
    call himalaya_ui#notifications#info('Deleted.')
  endif

  if self.himalayaui.is_tmp_location_buffer(himalaya, item.file_path)
    let choice = confirm('Are you sure you want to delete query?', "&Yes\n&No")
    if choice !=? 1
      return
    endif

    call delete(item.file_path)
    call filter(himalaya.buffers.list, 'v:val !=? item.file_path')
    call himalaya_ui#notifications#info('Deleted.')
  endif

  let win = bufwinnr(item.file_path)
  if  win > -1
    silent! exe win.'wincmd w'
    silent! exe 'b#'
  endif

  silent! exe 'bw!'.bufnr(item.file_path)
  call self.focus()
  call self.render()
endfunction

function! s:drawer.toggle_himalaya(himalaya) abort
  if !a:himalaya.expanded
    return a:himalaya
  endif

  call self.load_saved_queries(a:himalaya)

  call self.himalayaui.connect(a:himalaya)

  if !empty(a:himalaya.conn)
    call self.populate(a:himalaya)
  endif
endfunction

function! s:drawer.populate(himalaya) abort
  if empty(a:himalaya.conn) && a:himalaya.conn_tried
    call self.himalayaui.connect(a:himalaya)
  endif
  if a:himalaya.schema_support
    return self.populate_schemas(a:himalaya)
  endif
  return self.populate_tables(a:himalaya)
endfunction

function! s:drawer.load_saved_queries(himalaya) abort
  if !empty(a:himalaya.save_path)
    let a:himalaya.saved_queries.list = split(glob(printf('%s/*', a:himalaya.save_path)), "\n")
  endif
endfunction

function! s:drawer.populate_tables(himalaya) abort
  let a:himalaya.tables.list = []
  if empty(a:himalaya.conn)
    return a:himalaya
  endif

  let tables = himalaya#adapter#call(a:himalaya.conn, 'tables', [a:himalaya.conn], [])

  let a:himalaya.tables.list = tables
  " Fix issue with sqlite tables listing as strings with spaces
  if a:himalaya.scheme =~? '^sqlite' && len(a:himalaya.tables.list) >=? 0
    let temp_table_list = []

    for table_index in a:himalaya.tables.list
      let temp_table_list += map(split(copy(table_index)), 'trim(v:val)')
    endfor

    let a:himalaya.tables.list = sort(temp_table_list)
  endif

  if a:himalaya.scheme =~? '^mysql'
    call filter(a:himalaya.tables.list, 'v:val !~? "mysql: [Warning\\]" && v:val !~? "Tables_in_"')
  endif

  call self.populate_table_items(a:himalaya.tables)
  return a:himalaya
endfunction

function! s:drawer.populate_table_items(tables) abort
  for table in a:tables.list
    if !has_key(a:tables.items, table)
      let a:tables.items[table] = {'expanded': 0 }
    endif
  endfor
endfunction

function! s:drawer.populate_schemas(himalaya) abort
  let a:himalaya.schemas.list = []
  if empty(a:himalaya.conn)
    return a:himalaya
  endif
  let scheme = himalaya_ui#schemas#get(a:himalaya.scheme)
  let schemas = scheme.parse_results(himalaya_ui#schemas#query(a:himalaya, scheme, scheme.schemes_query), 1)
  let tables = scheme.parse_results(himalaya_ui#schemas#query(a:himalaya, scheme, scheme.schemes_tables_query), 2)
  let schemas = filter(schemas, {i, v -> !self._is_schema_ignored(v)})
  let tables_by_schema = {}
  for [scheme_name, table] in tables
    if self._is_schema_ignored(scheme_name)
      continue
    endif
    if !has_key(tables_by_schema, scheme_name)
      let tables_by_schema[scheme_name] = []
    endif
    call add(tables_by_schema[scheme_name], table)
    call add(a:himalaya.tables.list, table)
  endfor
  let a:himalaya.schemas.list = schemas
  for schema in schemas
    if !has_key(a:himalaya.schemas.items, schema)
      let a:himalaya.schemas.items[schema] = {
            \ 'expanded': 0,
            \ 'tables': {
            \   'expanded': 1,
            \   'list': [],
            \   'items': {},
            \ },
            \ }

    endif
    let a:himalaya.schemas.items[schema].tables.list = sort(get(tables_by_schema, schema, []))
    call self.populate_table_items(a:himalaya.schemas.items[schema].tables)
  endfor
  return a:himalaya
endfunction

function! s:drawer.get_toggle_icon(type, item) abort
  if a:item.expanded
    return g:himalaya_ui_icons.expanded[a:type]
  endif

  return g:himalaya_ui_icons.collapsed[a:type]
endfunction

function! s:drawer.get_nested(obj, val, ...) abort
  let default = get(a:, '1', 0)
  let items = split(a:val, '->')
  let result = copy(a:obj)

  for item in items
    if !has_key(result, item)
      let result = default
      break
    endif
    let result = result[item]
  endfor

  return result
endfunction

function! s:drawer.get_buffer_name(himalaya, buffer)
  let name = fnamemodify(a:buffer, ':t')
  let is_tmp = self.himalayaui.is_tmp_location_buffer(a:himalaya, a:buffer)

  if !is_tmp
    return name
  endif

  if fnamemodify(name, ':r') ==? 'himalaya_ui'
    let name = fnamemodify(name, ':e')
  endif

  return substitute(name, '^'.himalaya_ui#utils#slug(a:himalaya.name).'-', '', '')
endfunction

function! s:drawer._is_schema_ignored(schema_name)
  for ignored_schema in g:himalaya_ui_hide_schemas
    if match(a:schema_name, ignored_schema) > -1
      return 1
    endif
  endfor
  return 0
endfunction

function! s:sort_himalayaout(a1, a2)
  return str2nr(fnamemodify(a:a1, ':t:r')) - str2nr(fnamemodify(a:a2, ':t:r'))
endfunction
