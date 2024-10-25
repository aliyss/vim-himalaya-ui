function! himalaya_ui#prompt#list(options) abort
  let options = map(copy(a:options), 'printf("%s (%d)", v:val.name, v:key + 1)')
  
  let index = inputlist(options)
  if index == ''
    throw 'Action aborted!'
  endif

  return a:options[index - 1]
endfunction

