function! himalaya_ui#utils#slug(str) abort
  return substitute(a:str, '[^A-Za-z0-9_\-]', '', 'g')
endfunction

function! himalaya_ui#utils#input(name, default) abort
  return input(a:name, a:default)
endfunction

function! himalaya_ui#utils#inputlist(list) abort
  return inputlist(a:list)
endfunction

function! himalaya_ui#utils#request_json(opts) abort
  call himalaya#request#json(a:opts)
endfunction

function! himalaya_ui#utils#request_json_sync(opts) abort
  let args = get(a:opts, 'args', [])
  call himalaya_ui#log#info(printf('%s…', a:opts.msg))
  let config = exists('g:himalaya_config_path') ? ' --config ' . g:himalaya_config_path : ''
  let cmd = call('printf', [g:himalaya_executable . config . ' --output json ' . a:opts.cmd] + args)
  try
    let content = himalaya_ui#job#start(cmd)
    let parsed_content = json_decode(join(content))
    return parsed_content
  catch /.*/
    call himalaya_ui#notifications#warning([
          \ 'Error executing command.',
          \ ])
  endtry
endfunction

function! himalaya_ui#utils#request_plain_sync(opts) abort
  let args = get(a:opts, 'args', [])
  call himalaya_ui#log#info(printf('%s…', a:opts.msg))
  let config = exists('g:himalaya_config_path') ? ' --config ' . g:himalaya_config_path : ''
  let cmd = call('printf', [g:himalaya_executable . config . ' --output plain ' . a:opts.cmd] + args)

  try
    let content = himalaya_ui#job#start(cmd)
    return content
  catch /.*/
    call himalaya_ui#notifications#warning([
          \ 'Error executing command.',
          \ ])
  endtry
endfunction

function! himalaya_ui#utils#readfile(file) abort
  try
    let content = readfile(a:file)
    let content = json_decode(join(content, "\n"))
    if type(content) !=? type([])
      throw 'Connections file not a valid array'
    endif
    return content
  catch /.*/
    call himalaya_ui#notifications#warning([
          \ 'Error reading connections file.',
          \ printf('Validate that content of file %s is valid json array.', a:file),
          \ "If it's empty, feel free to delete it."
          \ ])
    return []
  endtry
endfunction

function! himalaya_ui#utils#quote_query_value(val) abort
  if a:val =~? "^'.*'$" || a:val =~? '^[0-9]*$' || a:val =~? '^\(true\|false\)$'
    return a:val
  endif

  return "'".a:val."'"
endfunction

function! himalaya_ui#utils#set_mapping(key, plug, ...)
  let mode = a:0 > 0 ? a:1 : 'n'

  if hasmapto(a:plug, mode)
    return
  endif

  let keys = a:key
  if type(a:key) ==? type('')
    let keys = [a:key]
  endif

  for key in keys
    silent! exe mode.'map <silent><buffer><nowait> '.key.' '.a:plug
  endfor
endfunction

function! himalaya_ui#utils#print_debug(msg) abort
  if !g:himalaya_ui_debug
    return
  endif

  echom '[HIMALAYAUI Debug] '.string(a:msg)
endfunction


function! himalaya_ui#utils#find_window_by_var(varname, value)
    " Iterate over all windows
    for win_id in range(1, winnr('$'))
        " Get the current window ID
        let win = win_getid(win_id)
        " Check if the variable matches the desired value
        if getwinvar(win, a:varname, '') ==# a:value
            return win
        endif
    endfor
    " Return -1 if no matching window is found
    return -1
endfunction

function! himalaya_ui#utils#create_window_with_var(buffer_name, varname, value)
  let window_id = himalaya_ui#utils#find_window_by_var(a:varname, a:value)
  if window_id != -1
    call win_gotoid(window_id)
    let buf = bufexists(a:buffer_name) ? bufnr(a:buffer_name) : -1
    if buf != -1
      execute 'buffer ' . buf
    else
      execute 'enew'
      execute 'file ' . a:buffer_name
    endif
    return window_id
  endif

  execute printf('silent! rightbelow new %s', a:buffer_name)

  let window_id = win_getid()
  call setwinvar(window_id, a:varname, a:value)

  return window_id
endfunction


function! himalaya_ui#utils#get_buffer_width(bufnr) abort " https://newbedev.com/get-usable-window-width-in-vim-script
  let winnr = bufwinnr(a:bufnr)
  if winnr == -1
    return -1
  endif

  let width = winwidth(winnr)
  let numberwidth = max([&numberwidth, strlen(line('$'))+1])
  let numwidth = (&number || &relativenumber)? numberwidth : 0
  let foldwidth = &foldcolumn

  if &signcolumn == 'yes'
    let signwidth = 2
  elseif &signcolumn == 'auto'
    let signs = execute(printf('sign place buffer=%d', bufnr(a:bufnr)))
    let signs = split(signs, "\n")
    let signwidth = len(signs)>2? 2: 0
  else
    let signwidth = 0
  endif

  return width - numwidth - foldwidth - signwidth
endfunction

function! himalaya_ui#utils#get_buffer_height(bufnr) abort
  let winnr = bufwinnr(a:bufnr)
  if winnr == -1
    return -1
  endif

  let height = winheight(winnr)
  return height
endfunction

function! himalaya_ui#utils#get_email_id_from_line(line) abort
  return matchstr(a:line, '\d\+')
endfunction

function! himalaya_ui#utils#get_email_id_under_cursor() abort
  let line = getline('.')
  return himalaya_ui#utils#get_email_id_from_line(line)
endfunction

function! himalaya_ui#utils#get_email_id_from_lines(from, to) abort
  try
    let emails = []
    for line in range(a:from, a:to)
      let email_id = himalaya_ui#utils#get_email_id_from_line(getline(line))
      if email_id != ''
        call add(emails, email_id)
      endif
    endfor
    return emails
  catch
    call himalaya_ui#notifications#error([
          \ 'Emails not found.',
          \ ])
  endtry
endfunction

function! himalaya_ui#utils#get_email_id_under_cursors() abort
  let from = line("'<")
  let to = line("'>")
  return himalaya_ui#utils#get_email_id_from_lines(from, to)
endfunction
