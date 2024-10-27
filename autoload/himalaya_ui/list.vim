let s:list_instance = {}
let s:list = {}
let s:bind_param_rgx = '\(^\|[[:blank:]]\|[^:]\)\('.g:himalaya_ui_bind_param_pattern.'\)'

let s:window_info = {
      \ 'last_window_start_time': 0,
      \ 'last_window_time': 0
      \ }

function! himalaya_ui#list#new(drawer) abort
  let s:list_instance = s:list.new(a:drawer)
  return s:list_instance
endfunction

function! s:list.new(drawer) abort
  let instance = copy(self)
  let instance.drawer = a:drawer
  let instance.buffer_counter = {}
  let instance.last_list = []
  augroup himalayaui_async_lists
    autocmd!
    autocmd User *HIMALAYAExecutePre call s:start_list()
    autocmd User *HIMALAYAExecutePost call s:print_list_time()
  augroup END
  return instance
endfunction

function! s:list.open(item, edit_action) abort
  let himalaya = self.drawer.himalayaui.himalayas[a:item.himalayaui_himalaya_key_name]
  if a:item.type ==? 'buffer'
    return self.open_buffer(himalaya, a:item.file_path, a:edit_action)
  endif
  let label = get(a:item, 'label', '')
  let folder = ''
  let account = ''
  let id = ''
  if a:item.type !=? 'list'
    let suffix = a:item.folder.name.'-'.a:item.label
    let folder = a:item.folder.name
    let account = a:item.account
  elseif a:item.type ==? 'mail'
    let suffix = a:item.folder.name.'-'.a:item.label
    let folder = a:item.folder.name
    let account = a:item.account
    let id = a:item.id
  endif

  let suffix = a:item.folder.name.'-'.a:item.label
  let folder = a:item.folder.name
  let account = a:item.account

  let buffer_name = self.generate_buffer_name(himalaya, { 'account': account, 'folder': folder, 'label': label, 'id': id, 'filetype': himalaya.filetype, 'include_time': 0 })
  call self.open_buffer(himalaya, buffer_name, a:edit_action, { 'account': account, 'folder': folder, 'label': label, 'filetype': "himalaya-email-listing", 'content': get(a:item, 'content') })
endfunction

function! s:list.generate_buffer_name_email(opts) abort
  let include_time = get(a:opts, 'include_time', 1)
  let time = include_time ? (exists('*strftime') ? strftime('%Y-%m-%d-%H-%M-%S') : localtime()) : ''
  let suffix = 'mail'
  if !empty(a:opts.account)
    let suffix = printf('%s-%s', a:opts.account, a:opts.label)
  endif

  if !empty(a:opts.folder)
    let suffix = printf('%s-%s', suffix, a:opts.folder)
  endif

  if !empty(a:opts.id)
    let suffix = printf('%s-%s', suffix, a:opts.id)
  endif

  let buffer_name = himalaya_ui#utils#slug(printf('%s', suffix))
  if time !=? ''
    let buffer_name = printf('%s-%s', buffer_name, time)
  endif

  let tmp_name = printf('%s/%s', fnamemodify(tempname(), ':p:h'), buffer_name)
  return tmp_name
endfunction

function! s:list.generate_buffer_name(himalaya, opts) abort
  let include_time = get(a:opts, 'include_time', 1)
  let time = include_time ? (exists('*strftime') ? strftime('%Y-%m-%d-%H-%M-%S') : localtime()) : ''
  let suffix = 'list'
  if !empty(a:opts.account)
    let suffix = printf('%s-%s', a:opts.account, a:opts.label)
  endif

  if !empty(a:opts.folder)
    let suffix = printf('%s-%s', suffix, a:opts.folder)
  endif

  if !empty(a:opts.id)
    let suffix = printf('%s-%s', suffix, a:opts.id)
  endif

  let buffer_name = himalaya_ui#utils#slug(printf('%s-%s', a:himalaya.name, suffix))
  if time !=? ''
    let buffer_name = printf('%s-%s', buffer_name, time)
  endif
  if type(g:himalaya_ui_buffer_name_generator) ==? type(function('tr'))
    let buffer_name = printf('%s-%s', a:himalaya.name, call(g:himalaya_ui_buffer_name_generator, [a:opts]))
  endif

  if !empty(self.drawer.himalayaui.tmp_location)
    return printf('%s/%s', self.drawer.himalayaui.tmp_location, buffer_name)
  endif

  let tmp_name = printf('%s/%s', fnamemodify(tempname(), ':p:h'), buffer_name)
  call add(a:himalaya.buffers.tmp, tmp_name)
  return tmp_name
endfunction

function! s:list.focus_window() abort
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

function s:list.pretty_print_list(content) abort
  let table = []
  let header = []
  let max_width = {}
  for row in a:content
    for [key, value] in items(row)
      let max_width[key] = max([len(key), get(max_width, key, 0)])
      let max_width[key] = max([len(value), get(max_width, key, 0)])
    endfor
  endfor

  for row in a:content
    let line = []
    for [key, value] in items(row)
      let line += [printf('%s: %s', key, value)]
    endfor
    call add(table, line)

    if len(header) ==? 0
      let header = keys(row)
    endif
  endfor

  let table = [header] + table
  let table = map(table, {i, row -> map(copy(row), {j, col -> printf('%-'.max_width[header[j]].'s', col)})})
  let table = map(table, {i, row -> join(row, ' | ')})
  let table = join(table, "\n")

  return table
endfunction


function! s:list.refresh(view) abort
  let folder = b:himalayaui_folder_name
  let account = b:himalayaui_account_name

  if a:view ==? "list"
    call self.list_folder_items(folder, account, 'himalaya-email-listing')
  else
  endif
endfunction

function! s:bufwidth(bufnr) abort " https://newbedev.com/get-usable-window-width-in-vim-script
  let width = winwidth(a:bufnr)
  echom width
  let numberwidth = max([&numberwidth, strlen(line('$'))+1])
  let numwidth = (&number || &relativenumber)? numberwidth : 0
  let foldwidth = &foldcolumn

  if &signcolumn == 'yes'
    let signwidth = 2
  elseif &signcolumn == 'auto'
    let signs = execute(printf('sign place buffer=%d', bufnr('')))
    let signs = split(signs, "\n")
    let signwidth = len(signs)>2? 2: 0
  else
    let signwidth = 0
  endif
  return width - numwidth - foldwidth - signwidth
endfunction

function! s:list.list_folder_items(folder, account, filetype) abort
  let content = himalaya_ui#utils#request_plain_sync({
    \ 'cmd': 'envelope list --folder %s --account %s --page %d',
    \ 'args': [shellescape(a:folder), shellescape(a:account), 1],
    \ 'msg': 'Listing mail',
    \})

  " TODO: Use this instead of the above 
  " let content = himalaya_ui#utils#request_plain_sync({
  " \ 'cmd': 'envelope list --folder %s --account %s --max-width %d --page-size %d --page %d',
  " \ 'args': [shellescape(folder), shellescape(account), s:bufwidth(bufnr+1), winheight(bufnr) - 2, 1],
  " \ 'msg': 'Listing mail',
  " \})

  silent! exe 'setlocal filetype='.a:filetype.' buftype=nofile bufhidden=wipe nobuflisted nolist noswapfile nowrap nospell nomodifiable signcolumn=no'

  " TODO: Add a help message to the buffer
  " nnoremap <silent><buffer> ? :call <sid>method('toggle_help', 'himalaya-email-listing')<CR>
  nnoremap <silent><buffer> <CR> :call <sid>method('show_email', 'list')<CR>
  nnoremap <silent><buffer> r :call <sid>method('reply_email', 'list')<CR>
  nnoremap <silent><buffer> R :call <sid>method('refresh', 'list')<CR>
  nnoremap <silent><buffer> F :call <sid>method('forward_email', 'list')<CR>
  nnoremap <silent><buffer> dd :call <sid>method('delete_email', 'list')<CR>

  augroup himalaya_ui
    autocmd! * <buffer>
  augroup END

  setlocal modifiable
  silent 1,$delete _
  silent execute '%d'
  call append(0, himalaya_ui#display#as_table(content))
  silent execute '$d'
  setlocal nomodifiable

  return
endfunction

function s:list.open_buffer(himalaya, buffer_name, edit_action, ...) abort
  let opts = get(a:, '1', {})
  let folder = get(opts, 'folder', '')
  let account = get(opts, 'account', '')
  let default_content = get(opts, 'content', g:himalaya_ui_default_list)
  let was_single_win = winnr('$') ==? 1

  " TODO: Apart from the rest, this part is also a mess.
  " - Remove the buffer created in setup_buffer
  "   - Instead use a temporary buffer
  "   - If the buffer is already open, use it and overwrite the content
  " - Listing is not working properly
  "   - Content is not adjusted to the window size
  "   - Helper s:bufwidth is provided

  if a:edit_action ==? 'edit'
    call self.focus_window()
    let bufnr = bufnr(a:buffer_name)
    if bufnr > -1
      silent! exe 'b '.bufnr
      call self.setup_buffer(a:himalaya, extend({'existing_buffer': 1 }, opts), a:buffer_name, was_single_win)
      call self.list_folder_items(folder, account, opts.filetype)
      return
    endif
  endif

  if empty(folder)
    return
  endif

  silent! exe a:edit_action.' '.a:buffer_name
  call self.setup_buffer(a:himalaya, opts, a:buffer_name, was_single_win)

  call self.focus_window()
  let bufnr = bufnr(a:buffer_name)

  call self.list_folder_items(folder, account, opts.filetype)
  let optional_schema = account ==? a:himalaya.default_scheme ? '' : account

  if !empty(optional_schema)
    if a:himalaya.quote
      let optional_schema = '"'.optional_schema.'"'
    endif
    let optional_schema = optional_schema.'.'
  endif

  " let content = substitute(default_content, '{table}', table, 'g')
  " let content = substitute(content, '{optional_schema}', optional_schema, 'g')
  " let content = substitute(content, '{schema}', schema, 'g')
  " let himalaya_name = !empty(schema) ? schema : a:himalaya.himalaya_name
  " let content = substitute(content, '{himalayaname}', himalaya_name, 'g')
  " let content = substitute(content, '{last_list}', join(self.last_list, "\n"), 'g')
  " silent 1,$delete _
  " call setline(1, split(content, "\n"))
  " if g:himalaya_ui_auto_execute_table_helpers
  "   if g:himalaya_ui_execute_on_save
  "     write
  "   else
  "     call self.execute_list()
  "   endif
  " endif
endfunction

function! s:list.setup_email_buffer(himalaya, opts, buffer_name, was_single_win) abort
  call self.resize_if_single(a:was_single_win)
  let b:himalayaui_himalaya_key_name = a:himalaya.key_name
  let b:himalayaui_folder_name = get(a:opts, 'folder', '')
  let b:himalayaui_account_name = get(a:opts, 'account', '')
  let b:himalaya = a:himalaya
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
endfunction

function! s:list.setup_buffer(himalaya, opts, buffer_name, was_single_win) abort
  call self.resize_if_single(a:was_single_win)
  let b:himalayaui_himalaya_key_name = a:himalaya.key_name
  let b:himalayaui_folder_name = get(a:opts, 'folder', '')
  let b:himalayaui_account_name = get(a:opts, 'account', '')
  let b:himalaya = a:himalaya
  let is_existing_buffer = get(a:opts, 'existing_buffer', 0)
  let is_tmp = self.drawer.himalayaui.is_tmp_location_buffer(a:himalaya, a:buffer_name)
  let himalaya_buffers = self.drawer.himalayaui.himalayas[a:himalaya.key_name].buffers

  if index(himalaya_buffers.list, a:buffer_name) ==? -1
    if empty(himalaya_buffers.list)
      let himalaya_buffers.expanded = 1
    endif
    " call add(himalaya_buffers.list, a:buffer_name)
    call self.drawer.render()
  endif


  " if &filetype !=? a:himalaya.filetype || !is_existing_buffer
  "   silent! exe 'setlocal filetype='.a:himalaya.filetype.' nomodifiable'
  " endif
  " let is_sql = &filetype ==? a:himalaya.filetype
  " nnoremap <silent><buffer><Plug>(HIMALAYAUI_ExecuteQuery) :call <sid>method('execute_list')<CR>
  " vnoremap <silent><buffer><Plug>(HIMALAYAUI_ExecuteQuery) :<C-u>call <sid>method('execute_list', 1)<CR>
  " if is_tmp && is_sql
    " nnoremap <silent><buffer><silent><Plug>(HIMALAYAUI_SaveQuery) :call <sid>method('save_list')<CR>
  " endif
  " augroup himalaya_ui_list
  "   autocmd! * <buffer>
  "   if g:himalaya_ui_execute_on_save && is_sql
  "     autocmd BufWritePost <buffer> nested call s:method('execute_list')
  "   endif
  "   autocmd BufDelete,BufWipeout <buffer> silent! call s:method('remove_buffer', str2nr(expand('<abuf>')))
  " augroup END
endfunction

function! s:method(name, ...) abort
  if a:0 > 0
    return s:list_instance[a:name](a:1)
  endif

  return s:list_instance[a:name]()
endfunction

function! s:list.resize_if_single(is_single_win) abort
  if a:is_single_win
    exe self.drawer.get_winnr().'wincmd w'
    exe 'vertical resize '.g:himalaya_ui_winwidth
    wincmd p
  endif
endfunction

function! s:list.show_email(view) abort
  let folder = b:himalayaui_folder_name
  let account = b:himalayaui_account_name
  if a:view ==? "list"
    let id = matchstr(getline("."), '\d\+') 
  else
    let id = b:himalayaui_current_email
  endif

  let content = himalaya_ui#utils#request_plain_sync({
  \ 'cmd': 'message read --account %s --folder %s %s',
  \ 'args': [shellescape(account), shellescape(folder), id],
  \ 'msg': 'Retrieving mail',
  \})
  let content = himalaya_ui#display#as_email(content)

  let buffer_name = self.generate_buffer_name_email({ 'account': account, 'folder': folder, 'label': 'ReadMail', 'id': id, 'filetype': 'himalaya-email-reading', 'include_time': 0 })


  execute printf('silent! rightbelow new %s', buffer_name)
  setlocal modifiable
  silent execute '%d'
  call append(0, content)
  silent execute '$d'
  setlocal filetype=himalaya-email-reading
  let &modified = 0
  execute 0

  " TODO: Add a help message to the buffer
  " nnoremap <silent><buffer> ? :call <sid>method('toggle_help', 'himalaya-email-reading')<CR>
  nnoremap <silent><buffer> R :call <sid>method('reply_email', 'mail')<CR>
  nnoremap <silent><buffer> F :call <sid>method('forward_email', 'mail')<CR>
  nnoremap <silent><buffer> D :call <sid>method('delete_email', 'mail')<CR>

  let b:himalayaui_folder_name = folder
  let b:himalayaui_account_name = account
  let b:himalayaui_current_email = id
  let b:himalayaui_current_buffer_name = buffer_name

  augroup himalaya_ui
    autocmd! * <buffer>
  augroup END
endfunction


function! s:list.reply_email(view) abort
  let folder = b:himalayaui_folder_name
  let account = b:himalayaui_account_name

  if a:view ==? "list"
    let id = matchstr(getline("."), '\d\+') 
  else
    let id = b:himalayaui_current_email
    let current_buffer_name = b:himalayaui_current_buffer_name
    " TODO: Don't know if this is the right way to do it
    execute printf('silent! bwipeout %s', current_buffer_name)
  endif

  let content = himalaya_ui#utils#request_plain_sync({
  \ 'cmd': 'template reply --account %s --folder %s %s',
  \ 'args': [shellescape(account), shellescape(folder), id],
  \ 'msg': 'Fetching reply template',
  \})

  let content = himalaya_ui#display#as_email(content)

  let buffer_name = self.generate_buffer_name_email({ 'account': account, 'folder': folder, 'label': 'ReplyMail', 'id': id, 'filetype': 'himalaya-email-writing', 'include_time': 0 })

  " TODO: Same as above. I think this can be done in a better way
  execute printf('silent! rightbelow new %s', buffer_name)
  setlocal modifiable
  silent execute '%d'
  call append(0, content)
  silent execute '$d'
  setlocal filetype=himalaya-email-writing
  let &modified = 0
  execute 0


  let b:himalayaui_folder_name = folder
  let b:himalayaui_account_name = account
  let b:himalayaui_current_email = id
  let b:himalayaui_current_buffer_name = buffer_name

  nnoremap <silent><buffer><Plug>(HIMALAYAUI_ExecuteQuery) :call <sid>method('execute_mail_prompt')<CR>
  vnoremap <silent><buffer><Plug>(HIMALAYAUI_ExecuteQuery) :<C-u>call <sid>method('execute_mail_prompt', 1)<CR>


  augroup himalaya_ui_list
    autocmd! * <buffer>
    if g:himalaya_ui_execute_on_save
      autocmd BufWritePost <buffer> nested call s:method('execute_mail_prompt')
    endif
    autocmd BufDelete,BufWipeout <buffer> silent! call s:method('remove_buffer', str2nr(expand('<abuf>')))
  augroup END
endfunction


function! s:list.forward_email(view) abort
  let folder = b:himalayaui_folder_name
  let account = b:himalayaui_account_name

  if a:view ==? "list"
    let id = matchstr(getline("."), '\d\+') 
  else
    let id = b:himalayaui_current_email
    let current_buffer_name = b:himalayaui_current_buffer_name
    " TODO: Don't know if this is the right way to do it
    execute printf('silent! bwipeout %s', current_buffer_name)
  endif

  let content = himalaya_ui#utils#request_plain_sync({
  \ 'cmd': 'template forward --account %s --folder %s %s',
  \ 'args': [shellescape(account), shellescape(folder), id],
  \ 'msg': 'Fetching forward template',
  \})

  let content = himalaya_ui#display#as_email(content)

  let buffer_name = self.generate_buffer_name_email({ 'account': account, 'folder': folder, 'label': 'ReplyMail', 'id': id, 'filetype': 'himalaya-email-writing', 'include_time': 0 })

  " TODO: Same as above. I think this can be done in a better way
  execute printf('silent! rightbelow new %s', buffer_name)
  setlocal modifiable
  silent execute '%d'
  call append(0, content)
  silent execute '$d'
  setlocal filetype=himalaya-email-writing
  let &modified = 0
  execute 0


  let b:himalayaui_folder_name = folder
  let b:himalayaui_account_name = account
  let b:himalayaui_current_email = id
  let b:himalayaui_current_buffer_name = buffer_name

  nnoremap <silent><buffer><Plug>(HIMALAYAUI_ExecuteQuery) :call <sid>method('execute_mail_prompt')<CR>
  vnoremap <silent><buffer><Plug>(HIMALAYAUI_ExecuteQuery) :<C-u>call <sid>method('execute_mail_prompt', 1)<CR>


  augroup himalaya_ui_list
    autocmd! * <buffer>
    if g:himalaya_ui_execute_on_save
      autocmd BufWritePost <buffer> nested call s:method('execute_mail_prompt')
    endif
    autocmd BufDelete,BufWipeout <buffer> silent! call s:method('remove_buffer', str2nr(expand('<abuf>')))
  augroup END
endfunction

function! s:list.delete_email(view)
  if a:view ==? "list"
    let id = matchstr(getline("."), '\d\+') 
  else
    let id = b:himalayaui_current_email
    let current_buffer_name = b:himalayaui_current_buffer_name
    " TODO: Don't know if this is the right way to do it
    execute printf('silent! bwipeout %s', current_buffer_name)
  endif
  let choice = input(printf('Are you sure you want to delete email(s) %s? (y/N) ', id))
  redraw | echo
  if choice != 'y' | return | endif

  let account = b:himalayaui_account_name
  let folder = b:himalayaui_folder_name

  call himalaya_ui#utils#request_plain_sync({
    \ 'cmd': 'message delete --account %s --folder %s %s',
    \ 'args': [shellescape(account), shellescape(folder), id],
    \ 'msg': 'Deleting email',
    \})

  if a:view ==? "list"
    " let id = matchstr(getline("."), '\d\+') 
  else
    " let id = b:himalayaui_current_email
    let current_buffer_name = b:himalayaui_current_buffer_name
    " TODO: Don't know if this is the right way to do it
    execute printf('silent! bwipeout %s', current_buffer_name)
  endif

  " if a:view ==? "list"
  "   " TODO: refresh the list
  "   " call self.method('refresh', 'list')
  " endif

  return
endfunction

function! s:list.execute_mail_prompt(...)
  try
    let account = b:himalayaui_account_name
    let current_buffer_name = b:himalayaui_current_buffer_name
    while 1
      let choice = input('(s)end, (d)raft, (q)uit or (c)ancel? ')
      let choice = tolower(choice)[0]
      redraw | echo

      if choice == 's'
	      call writefile(getline(1, '$'), current_buffer_name)

        let content = himalaya_ui#utils#request_plain_sync({
          \ 'cmd': 'template send --account %s < %s',
          \ 'args': [shellescape(account), shellescape(current_buffer_name)],
          \ 'msg': 'Sending email',
          \})

        " TODO: Don't know if this is the right way to do it
        execute printf('silent! bwipeout %s', current_buffer_name)

        return
      elseif choice == 'd'
	      call writefile(getline(1, '$'), current_buffer_name)
        let content = himalaya_ui#utils#request_plain_sync({
          \ 'cmd': 'template save --account %s --folder drafts < %s',
          \ 'args': [shellescape(account), shellescape(current_buffer_name)],
          \ 'msg': 'Saving draft',
          \})

        " TODO: Don't know if this is the right way to do it
        execute printf('silent! bwipeout %s', current_buffer_name)

        return
      elseif choice == 'q'
        return
      elseif choice == 'c'
        " call himalaya#domain#email#write(join(getline(1, '$'), "\n") . "\n")
        throw 'Prompt:Interrupt'
      endif
    endwhile
  catch
    if v:exception =~ ':Interrupt$'
      call interrupt()
    else
      call himalaya_ui#log#err(v:exception)
    endif
  endtry
endfunction


function! s:list.remove_buffer(bufnr)
  let himalayaui_himalaya_key_name = getbufvar(a:bufnr, 'himalayaui_himalaya_key_name')
  let list = self.drawer.himalayaui.himalayas[himalayaui_himalaya_key_name].buffers.list
  let tmp = self.drawer.himalayaui.himalayas[himalayaui_himalaya_key_name].buffers.tmp
  call filter(list, 'v:val !=? bufname(a:bufnr)')
  call filter(tmp, 'v:val !=? bufname(a:bufnr)')
  return self.drawer.render()
endfunction

