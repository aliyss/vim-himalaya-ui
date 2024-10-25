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
